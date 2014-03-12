//
//  DMSDKEventManager.m
//  DistimoSDK
//
//  Created by Arne de Vries on 5/9/12.
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

#import "DMSDKEventManager.h"
#import "DMSDKSettingsManager.h"
#import "DMSDKPasteboardManager.h"
#import "DMSDKApplicationManager.h"

#import "DMSDKEvent.h"
#import "DistimoSDK.h"

#define MIN_DELAY			0.0
#define MAX_DELAY			16.0
#define BACKGROUND_DURATION	15.0

@implementation DMSDKEventManager

@synthesize eventQueue = _eventQueue;
@synthesize storeLock = _storeLock;

@synthesize urlConnection = _urlConnection;
@synthesize webView = _webView;
@synthesize delay = _delay;
@synthesize currentEvent = _currentEvent;

@synthesize backgroundConnectivityEnabled = _backgroundConnectivityEnabled;
@synthesize didEnterBackground = _didEnterBackground;
@synthesize backgroundTask = _backgroundTask;
@synthesize backgroundTimer = _backgroundTimer;

#pragma mark - Deallocation

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self.urlConnection cancel];
	self.urlConnection = nil;
	
	[self.webView setDelegate:nil];
	self.webView = nil;
	
	self.eventQueue = nil;
	self.storeLock = nil;
	self.currentEvent = nil;
	
	[self.backgroundTimer invalidate];
	self.backgroundTimer = nil;
	
	[super dealloc];
}

#pragma mark - Initialization

+ (DMSDKEventManager *)sharedInstance {
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
		NSMutableArray *eventQueue = [[NSMutableArray alloc] init];
		self.eventQueue = eventQueue;
		[eventQueue release];
		
		NSLock *storeLock = [[NSLock alloc] init];
		self.storeLock = storeLock;
		[storeLock release];
		
		[self resetDelay];
		
		self.backgroundConnectivityEnabled = NO;
		self.backgroundTask = UIBackgroundTaskInvalid;
		
		//Listen for application state changes
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:DMApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:DMApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:DMApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationCrashed:) name:DMApplicationCrashedNotification object:nil];
		
		//Check for an already active application (for plugins that do not start the SDK on didFinishLaunching)
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			[self applicationDidBecomeActive:nil];
		}
	}
	
	return self;
}

#pragma mark - Public methods

- (void)logEvent:(DMSDKEvent *)event {
	DMLog(@"%@", event);
	
	if (self.backgroundTask != UIBackgroundTaskInvalid || [sharedApplicationManager applicationState] == DMApplicationStateActive) {
		[self queueEvent:event];
	} else {
		[self storeEvent:event];
	}
}

#pragma mark - Private methods

- (void)reAddCurrentEvent {
	if (self.currentEvent) {
		DMSDKEvent *event = [self.currentEvent retain];
		[self logEvent:event];
		[event release];
	}
}

- (NSString *)userAgent {
	static NSString *_userAgent = nil;
	
	if (!_userAgent) {
		@synchronized (self) {
			if (!_userAgent) {
				NSString *appName = [[DMSDKApplicationManager applicationBundle] objectForInfoDictionaryKey:@"CFBundleName"];
				NSString *appVersion = [[DMSDKApplicationManager applicationBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
				_userAgent = [[NSString stringWithFormat:@"%@/%@ %@", appName, appVersion, USER_AGENT_SUFFIX] retain];
			}
		}
	}
	
	return _userAgent;
}

#pragma mark - Queuing and Storing

- (void)queueEvent:(DMSDKEvent *)event {
	DMLog(@"%@", event.name);
	
	@synchronized (self.eventQueue) {
		if (event) {
			[self.eventQueue addObject:event];
		}
		
		//If there is only one event in the queue, send it immediately
		if ([self.eventQueue count] == 1) {
			[self sendEvent:event];
		}
	}
}

- (void)storeEvent:(DMSDKEvent *)event {
	DMLog(@"%@", event.name);
	
	if (event) {
		[self.storeLock lock];
		
		NSArray *events = [sharedPasteboardManager distributedValueForKey:PASTEBOARD_EVENTS_KEY];
		NSMutableArray *newEvents = [NSMutableArray arrayWithArray:events];
		[newEvents addObject:event];
		[sharedPasteboardManager setDistributedValue:[NSArray arrayWithArray:newEvents] forKey:PASTEBOARD_EVENTS_KEY];
	
		[self.storeLock unlock];
	}
}

#pragma mark - Background

- (void)applicationDidBecomeActive:(NSNotification *)notification {
	DMPrettyLog
	
	[self stopBackgroundTask];
	[self stopBackgroundTimer];
	
	//Get the events from the pasteboard
	NSArray *events = [sharedPasteboardManager distributedValueForKey:PASTEBOARD_EVENTS_KEY];
	
	//Remove stored events from pasteboard
	[sharedPasteboardManager setDistributedValue:nil forKey:PASTEBOARD_EVENTS_KEY];
	
	if ([events count] > 0) {
		@synchronized (self.eventQueue) {
			//Add the events from the pasteboard to the event queue (should be empty)
			[self.eventQueue addObjectsFromArray:events];
			
			//Send the first event
			DMSDKEvent *event = [self.eventQueue objectAtIndex:0];
			[self sendEvent:event];
		}
	}
}

- (void)applicationWillResignActive:(NSNotification *)notification {
	DMPrettyLog
	
	if (self.backgroundConnectivityEnabled) {
		[self startBackgroundTask];
	} else {
		[self applicationWillSuspend];
	}
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
	DMPrettyLog
	
	if (self.backgroundConnectivityEnabled) {
		self.didEnterBackground = YES;
	}
	
	[self startBackgroundTimer];
}

- (void)applicationCrashed:(NSNotification *)notification {
	DMPrettyLog
	
	[self applicationWillSuspend];
}

- (void)applicationWillSuspend {
	DMPrettyLog
	
	@synchronized (self.eventQueue) {
		if ([self.eventQueue count]) {
			DMLog(@"Storing %d events to pasteboard", [self.eventQueue count]);
			
			//Prevent next event being sent
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedSendNextEvent) object:nil];
			
			//Stop sending events
			[self.urlConnection cancel];
			self.urlConnection = nil;
			
			//Clear current event
			self.currentEvent = nil;
			
			//Copy memory queue to pasteboard queue
			[sharedPasteboardManager setDistributedValue:[NSArray arrayWithArray:self.eventQueue] forKey:PASTEBOARD_EVENTS_KEY];
			
			//Clear the memory queue
			[self.eventQueue removeAllObjects];
		}
	}
	
	[self stopBackgroundTask];
}

- (void)startBackgroundTask {
	DMPrettyLog
	
	//Start task completion untill all events are sent
	UIBackgroundTaskIdentifier aBackgroundTask = UIBackgroundTaskInvalid;
	aBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		[self applicationWillSuspend];
	}];
	self.backgroundTask = aBackgroundTask;
}

- (void)stopBackgroundTask {
	if (self.backgroundTask != UIBackgroundTaskInvalid) {
		DMLog(@"Stopping backgroundTask");
		
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
		self.backgroundTask = UIBackgroundTaskInvalid;
	}
	
	[self stopBackgroundTimer];
	
	self.didEnterBackground = NO;
}

- (void)startBackgroundTimer {
	NSTimeInterval duration = MIN(BACKGROUND_DURATION, [[UIApplication sharedApplication] backgroundTimeRemaining]);
	
	[self.backgroundTimer invalidate];
	self.backgroundTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(onBackgroundTimer:) userInfo:nil repeats:NO];
}

- (void)stopBackgroundTimer {
	[self.backgroundTimer invalidate];
	self.backgroundTimer = nil;
}

- (void)onBackgroundTimer:(NSTimer *)timer {
	[self stopBackgroundTimer];
	[self applicationWillSuspend];
}

#pragma mark - Sending

- (void)sendEvent:(DMSDKEvent *)event {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:event waitUntilDone:NO];
		return;
	}
	
	self.currentEvent = event;
	
	NSString *parameterString = [event urlParamString];
	DMLog(@"%@ (%d bytes postData) (%@)", event.name, [event.postData length], parameterString);
	
	NSString *urlString = [NSString stringWithFormat:@"%@?%@", EVENT_URL, parameterString];
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
	if ([event.postData length]) {
		[urlRequest setHTTPMethod:@"POST"];
		[urlRequest setHTTPBody:event.postData];
	}
	
	if (event.method == DMSDKEventMethodWebView) {
		DMLog(@"Sending using UIWebView %@ method", [urlRequest HTTPMethod]);
		
		UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 480.0f)];
		[webView setDelegate:self];
		[webView loadRequest:urlRequest];
		self.webView = webView;
		[webView release];
	} else {
		DMLog(@"Sending using NSURLConnection %@ method", [urlRequest HTTPMethod]);
		
		_urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:YES];
	}
}

- (void)sendNextEvent {
	[self performSelector:@selector(delayedSendNextEvent) withObject:nil afterDelay:self.delay];
}

- (void)delayedSendNextEvent {
	@synchronized (self.eventQueue) {
		if (self.currentEvent) {
			self.currentEvent = nil;
			[self.eventQueue removeObjectAtIndex:0];
		}
		
		if ([self.eventQueue count] > 0) {
			DMSDKEvent *event = [self.eventQueue objectAtIndex:0];
			[self sendEvent:event];
		} else {
			DMLog(@"No more events to send");
			
			if (self.didEnterBackground) {
				[self stopBackgroundTask];
			}
		}
	}
}

- (void)increaseDelay {
	NSTimeInterval result = self.delay;
	
	if (self.delay == MIN_DELAY) {
		result = 1.0;
	} else if (self.delay < MAX_DELAY) {
		result *= 2.0;
	}
	
	if (result != self.delay) {
		DMLog(@"Increasing delay to %.1f seconds", result);
		self.delay = result;
	}
}

- (void)resetDelay {
	if (self.delay != MIN_DELAY) {
		DMLog(@"Resetting delay to %.1f seconds", MIN_DELAY);
		self.delay = MIN_DELAY;
	}
}

#pragma mark NSURLConnectionDelegate methods

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
	//Check for done URL scheme
    if([[request.URL absoluteString] hasPrefix:@"done://"]) {
		DMLog(@"%@", [request.URL absoluteString]);
		
        [self.urlConnection cancel];
		self.urlConnection = nil;
		
		[self sendNextEvent];
		
		return nil;
	}
	
	//Set User-Agent
	if (![request valueForHTTPHeaderField:@"User-Agent"] || [[request valueForHTTPHeaderField:@"User-Agent"] rangeOfString:USER_AGENT_SUFFIX].location == NSNotFound) {
		NSString *userAgent = [self userAgent];
		DMLog(@"Setting User-Agent to %@", userAgent);
		
		NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:request.URL];
		[newRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
		[newRequest setHTTPMethod:request.HTTPMethod];
		[newRequest setHTTPBody:request.HTTPBody];
		
		[_urlConnection release];
		_urlConnection = [[NSURLConnection alloc] initWithRequest:newRequest delegate:self startImmediately:YES];
		
		return nil;
	}
	
	DMLog(@"Opening %@", [request.URL absoluteString]);
	
	return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	DMLog(@"Received response: %d %@", [(NSHTTPURLResponse *)response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[(NSHTTPURLResponse *)response statusCode]]);
	
	if ([(NSHTTPURLResponse *)response statusCode] != 200) {
        [self.urlConnection cancel];
		self.urlConnection = nil;
		
		//Re-add to the queue
		[self reAddCurrentEvent];
		
		//Increase delay
		[self increaseDelay];
		
		//Send next event after current delay
		[self sendNextEvent];
	}
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
	DMLog(@"Event body written: %d/%d (%d expected)", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	DMLog(@"Cleaning connection");
	
	[self.urlConnection cancel];
	self.urlConnection = nil;
	
	//Reset delay
	[self resetDelay];
	
	//Send next event
	[self sendNextEvent];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	DMLog(@"Error: %@", error);
	
	[self.urlConnection cancel];
	self.urlConnection = nil;
	
	//Re-add to the queue
	[self reAddCurrentEvent];
	
	//Increase delay
	[self increaseDelay];
	
	//Send next event after current delay
	[self sendNextEvent];
}

#pragma mark UIWebViewDelegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	
	DMLog(@"%@", [request.URL absoluteString]);
	
	if ([[request.URL absoluteString] hasPrefix:@"done://"]) {
		self.webView.delegate = nil;
		self.webView = nil;
		
		//Reset delay
		[self resetDelay];
		
		//Send next event
		[self sendNextEvent];
		
		return NO;
	}
	
	return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	if (self.currentEvent.requiresFingerprint) {
		DMLog(@"%@ - Waiting for done://", [webView.request.URL absoluteString]);
	} else {
		DMLog(@"%@ - Cleaning connection", [webView.request.URL absoluteString]);
		
		self.webView.delegate = nil;
		self.webView = nil;
		
		//Reset delay
		[self resetDelay];
		
		//Send next event
		[self sendNextEvent];
	}
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	DMLog(@"%@ Error: %@", [webView.request.URL absoluteString], error);
	
	self.webView.delegate = nil;
	self.webView = nil;
	
	//Re-add to the queue
	[self reAddCurrentEvent];
	
	//Increase delay
	[self increaseDelay];
	
	//Send next event after current delay
	[self sendNextEvent];
}

@end
