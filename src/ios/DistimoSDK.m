//
//  DistimoSDK.m
//  DistimoSDK
//
//  Created by Arne de Vries on 4/6/12.
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

#import "DistimoSDK.h"

#import "DMSDKIDManager.h"
#import "DMSDKEventLogger.h"
#import "DMSDKEventManager.h"
#import "DMSDKAppLinkManager.h"
#import "DMSDKPasteboardManager.h"
#import "DMSDKApplicationManager.h"

@implementation DistimoSDK

static BOOL _enabled = FALSE;

#pragma mark - Public methods

+ (NSString *)version {
	return VERSION;
}

+ (BOOL)handleLaunchWithOptions:(NSDictionary *)launchOptions
						 sdkKey:(NSString *)sdkKey
{
	//First set the SDK key
	_enabled = [DMSDKIDManager setSDKKey:sdkKey];
	
	if (_enabled) {
		dispatch_safe_sync(dispatch_get_main_queue(), ^{
			//Create the pasteboard manager
			[sharedPasteboardManager refreshPasteboards];
			
			//Create the ID manager (to generate IDs)
			sharedIDManager;
			
			//Create the application manager
			sharedApplicationManager;
			
			//Create the event manager
			sharedEventManager;
			
			//Handle launch
			[sharedApplicationManager handleApplicationLaunch];
			
			//Start the exception handler
			[sharedApplicationManager startUncaughtExceptionHandler];
		});
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
	
	return NO;
}

+ (void)logUserRegistered {
	if (_enabled) {
		[sharedEventLogger logUserRegistered];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

+ (void)logInAppPurchaseWithProductID:(NSString *)productID
						  priceLocale:(NSLocale *)priceLocale
								price:(double)price
							 quantity:(int)quantity
{
	if (_enabled) {
		[sharedEventLogger logInAppPurchaseWithProductID:productID
											 priceLocale:priceLocale
												   price:price
												quantity:quantity];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

+ (void)logInAppPurchaseWithProductID:(NSString *)productID
						 currencyCode:(NSString *)currencyCode
								price:(double)price
							 quantity:(int)quantity
{
	if (_enabled) {
		[sharedEventLogger logInAppPurchaseWithProductID:productID
											currencyCode:currencyCode
												   price:price
												quantity:quantity];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

+ (void)logExternalPurchaseWithProductID:(NSString *)productID
							 priceLocale:(NSLocale *)priceLocale
								   price:(double)price
								quantity:(int)quantity
{
	if (_enabled) {
		[sharedEventLogger logExternalPurchaseWithProductID:productID
												priceLocale:priceLocale
													  price:price
												   quantity:quantity];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

+ (void)logExternalPurchaseWithProductID:(NSString *)productID
							currencyCode:(NSString *)currencyCode
								   price:(double)price
								quantity:(int)quantity
{
	if (_enabled) {
		[sharedEventLogger logExternalPurchaseWithProductID:productID
											   currencyCode:currencyCode
													  price:price
												   quantity:quantity];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

+ (void)logBannerClickWithPublisher:(NSString *)publisher {
	if (_enabled) {
		[sharedEventLogger logBannerClickWithPublisher:publisher];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

#pragma mark User Properties

+ (void)setUserID:(NSString *)userID {
	if (_enabled) {
		[sharedEventLogger logUserID:userID];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

#pragma mark AppLink

+ (void)openAppLink:(NSString *)applinkHandle
		   campaign:(NSString *)campaignHandle
   inViewController:(UIViewController<SKStoreProductViewControllerDelegate> *)viewController
{
	if (_enabled) {
		if ([applinkHandle length]) {
			[sharedAppLinkManager openAppLink:applinkHandle
									 campaign:campaignHandle
									 uniqueID:[sharedIDManager UUID]
							 inViewController:viewController];
		}
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

#pragma mark - Private methods

+ (void)displaySDKKeyError:(NSString *)prettyMehod {
	NSLog(@"%@ ***** PLEASE PROVIDE A VALID SDK KEY *****", prettyMehod);
	
	if ([[UIDevice currentDevice].model hasSuffix:@" Simulator"]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Distimo SDK"
														message:@"Please provide a valid SDK Key"
													   delegate:nil
											  cancelButtonTitle:@"Dismiss"
											  otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

+ (void)enableBackgroundConnectivity:(BOOL)yesOrNo {
	if (_enabled) {
		[sharedEventManager setBackgroundConnectivityEnabled:yesOrNo];
	} else {
		[self displaySDKKeyError:DMPrettyMethod];
	}
}

@end
