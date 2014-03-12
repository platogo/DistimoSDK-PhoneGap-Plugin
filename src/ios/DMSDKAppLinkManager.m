//
//  DMSDKAppLinkManager.m
//  DistimoSDK
//
//  Created by Arne de Vries on 12/20/12.
//  Copyright (c) 2012 Distimo. All rights reserved.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import "DMSDKAppLinkManager.h"
#import "DMSDKApplicationManager.h"

#import "DistimoSDK.h"

#import <StoreKit/StoreKit.h>

#define REDIRECT_TIMEOUT 10.0

@implementation DMSDKAppLinkManager

@synthesize handlingConnection	= _handlingConnection;
@synthesize redirecting			= _redirecting;
@synthesize urlConnection		= _urlConnection;
@synthesize redirectURL			= _redirectURL;
@synthesize redirectTimer		= _redirectTimer;
@synthesize userAgent			= _userAgent;
@synthesize viewController		= _viewController;

- (void)dealloc {
	[self.urlConnection cancel];
	self.urlConnection = nil;
	
	self.redirectURL = nil;
	
	[self.redirectTimer invalidate];
	self.redirectTimer = nil;
	
	self.userAgent = nil;
	self.viewController = nil;
	
	[super dealloc];
}

+ (DMSDKAppLinkManager *)sharedInstance {
	static id _sharedInstance = nil;
	
	if (!_sharedInstance) {
		@synchronized (self) {
			if (!_sharedInstance) {
				_sharedInstance = [[self alloc] init];
			}
		}
	}
	
	return _sharedInstance;
}

- (id)init {
	if ((self = [super init])) {
		dispatch_safe_sync(dispatch_get_main_queue(), ^{
			UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
			self.userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
			[webView release];
		});
	}
	
	return self;
}

#pragma mark - Public methods

- (void)openAppLink:(NSString *)applinkHandle campaign:(NSString *)campaignHandle uniqueID:(NSString *)uniqueID inViewController:(UIViewController<SKStoreProductViewControllerDelegate> *)viewController {
	
	if (self.redirecting) {
		//Only one redirect simultaneously
		return;
	}
	
	self.redirecting = TRUE;
	
	//Store the viewController
	self.viewController = viewController;
	
	//Construct redirect URL
	NSString *redirectString = [NSString stringWithFormat:@"http://%@/%@/redirect?x=%@&u=%@", APPLINK_HOST, applinkHandle, (campaignHandle ? campaignHandle : @""), (uniqueID ? uniqueID : @"")];
	self.redirectURL = [NSURL URLWithString:redirectString];
	
	//Detach a new thread that will do the connection requests
	[NSThread detachNewThreadSelector:@selector(startConnectionRequestInBackground) toTarget:self withObject:nil];
}

#pragma mark - Private methods

- (void)handleRedirectFailure {
	//Cancel the connection
	[self.urlConnection cancel];
	self.urlConnection = nil;
	
	//Stop the background thread (will cleanup the timer)
	self.handlingConnection = NO;
	
	//Open self.redirectURL
	if ([[UIApplication sharedApplication] canOpenURL:self.redirectURL]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kDistimoSDKOpenAppLinkSuccessNotification object:nil];
		
		DMLog(@"Opening %@", [self.redirectURL absoluteString]);
		[[UIApplication sharedApplication] openURL:self.redirectURL];
	} else {
		DMLog(@"Cannot open %@", [self.redirectURL absoluteString]);
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDistimoSDKOpenAppLinkFailedNotification object:nil];
	}
	
	self.viewController	= nil;
	self.redirecting = FALSE;
}

#pragma mark - Connection methods

- (void)startConnectionRequestInBackground {
	DMPrettyLog
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	self.handlingConnection = YES;
	
	//Start the timeout timer
	self.redirectTimer = [NSTimer scheduledTimerWithTimeInterval:REDIRECT_TIMEOUT
														  target:self
														selector:@selector(redirectTimeout:)
														userInfo:nil
														 repeats:NO];
	
	//Create URL Request for the redirect
	DMLog(@"Redirecting to %@", [self.redirectURL absoluteString]);
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.redirectURL];
	
	//Set user-agent
	[urlRequest setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
	
	//Create URL Connection
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:YES];
	self.urlConnection = connection;
    [connection release];
	
	//Start the runloop
	while (self.handlingConnection) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	
	//Cleanup the timeout timer
	[self.redirectTimer invalidate];
	self.redirectTimer = nil;
	
	[pool release];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
	//This method is called in the background!
	
	DMLog(@"%@", [request.URL absoluteString]);
	
    if([[request.URL absoluteString] hasPrefix:@"itms-apps"]) {
		//Stop the connection
        [connection cancel];
        self.urlConnection = nil;
		
		//Stop the background thread (will cleanup the timer)
		self.handlingConnection = NO;
		
		//Show product
		dispatch_safe_sync(dispatch_get_main_queue(), ^{
			Class pvcClass = NSClassFromString(@"SKStoreProductViewController");
			Protocol *pvcProtocol = NSProtocolFromString(@"SKStoreProductViewControllerDelegate");
			
			if (pvcClass && self.viewController && [self.viewController conformsToProtocol:pvcProtocol]) {
				
				//Present an SKStoreProductViewController
				NSString *appstoreID = [[[[[[request.URL absoluteString] componentsSeparatedByString:@"?"] objectAtIndex:0] componentsSeparatedByString:@"/"] lastObject] stringByReplacingOccurrencesOfString:@"id" withString:@""];
				
				DMLog(@"Loading SKStoreProductViewController for productID %@", appstoreID);
				
				id productViewController = [[pvcClass alloc] init];
				[productViewController setDelegate:self.viewController];
				[productViewController loadProductWithParameters:[NSDictionary dictionaryWithObject:appstoreID forKey:@"id"]
												 completionBlock:^(BOOL result, NSError *error) {
													 if (result) {
														 [[NSNotificationCenter defaultCenter] postNotificationName:kDistimoSDKOpenAppLinkSuccessNotification object:nil];
														 
														 DMLog(@"Presenting SKStoreProductViewController for productID %@", appstoreID);
														 [self.viewController presentModalViewController:productViewController animated:YES];
													 } else {
														 DMLog(@"Error opening SKStoreProductViewController: %@", error);
														 [self handleRedirectFailure];
													 }
													 
													 [productViewController release];
													 
													 self.viewController = nil;
													 self.redirecting = FALSE;
												 }];
			} else {
				
				//Open the AppStore app
				DMLog(@"SKStoreProductViewController not available or no (proper) viewController to present in");
				
				if ([[UIApplication sharedApplication] canOpenURL:request.URL]) {
					[[NSNotificationCenter defaultCenter] postNotificationName:kDistimoSDKOpenAppLinkSuccessNotification object:nil];
					
					DMLog(@"Opening %@", [request.URL absoluteString]);
					[[UIApplication sharedApplication] openURL:request.URL];
				} else {
					DMLog(@"Cannot open %@", [request.URL absoluteString]);
					[self handleRedirectFailure];
				}
				
				self.viewController = nil;
				self.redirecting = FALSE;
			}
		});
		
        return nil;
	} else {
		return request;
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	//Receiving a response means the redirect failed
	int statuscode = [(NSHTTPURLResponse *)response statusCode];
	DMLog(@"Failed to redirect: %d %@", statuscode, [NSHTTPURLResponse localizedStringForStatusCode:statuscode]);
	
	[self handleRedirectFailure];
}

#pragma mark - Timer methods

- (void)redirectTimeout:(NSTimer *)timer {
	DMPrettyLog
	
	[self handleRedirectFailure];
}

@end
