//
//  DMSDKEventLogger.h
//  DistimoSDK
//
//  Created by Arne de Vries on 5/15/12.
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

#import "DistimoSDK+Configuration.h"

#define sharedEventLogger [DMSDKEventLogger sharedInstance]

@interface DMSDKEventLogger : NSObject {
	
}

@property (nonatomic, retain) NSNumberFormatter *currencyFormatter;

+ (DMSDKEventLogger *)sharedInstance;

- (void)logInternalEvent:(NSString *)eventName;
- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters;
- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters
				postData:(NSData *)postData;
- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters
		  requiresCookie:(BOOL)requiresCookie
	 requiresFingerprint:(BOOL)requiresFingerprint
				postData:(NSData *)postData;

#pragma mark - Launch Events

- (void)logFirstLaunchEvent;
- (void)logTamperedLaunchEvent;
- (void)logReinstallLaunchEvent;
- (void)logChangedIDEvent;

#pragma mark - User Value Events

- (void)logUserRegistered;
- (void)logInAppPurchaseWithProductID:(NSString *)productID
						  priceLocale:(NSLocale *)priceLocale
								price:(double)price
							 quantity:(int)quantity;
- (void)logInAppPurchaseWithProductID:(NSString *)productID
						 currencyCode:(NSString *)currencyCode
								price:(double)price
							 quantity:(int)quantity;
- (void)logExternalPurchaseWithProductID:(NSString *)productID
							 priceLocale:(NSLocale *)priceLocale
								   price:(double)price
								quantity:(int)quantity;
- (void)logExternalPurchaseWithProductID:(NSString *)productID
							currencyCode:(NSString *)currencyCode
								   price:(double)price
								quantity:(int)quantity;
- (void)logBannerClickWithPublisher:(NSString *)publisher;

#pragma mark - User Properties Events

- (void)logUserID:(NSString *)userID;

@end
