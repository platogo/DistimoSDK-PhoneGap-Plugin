//
//  DMSDKEventLogger.m
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

#import "DMSDKEventLogger.h"
#import "DMSDKEventManager.h"
#import "DMSDKIDManager.h"
#import "DMSDKSettingsManager.h"

#import "DMSDKEvent.h"

#import "DistimoSDK.h"

#define USER_REGISTERED_KEY		@"w5yRWg8xBRFOzGulO9tk"
#define USER_ID_KEY				@"ynmPmT0cR5hspOIdeYO4"

@implementation DMSDKEventLogger

@synthesize currencyFormatter = _currencyFormatter;

#pragma mark - Deallocation

- (void)dealloc {
	[_currencyFormatter release];
	
	[super dealloc];
}

#pragma mark - Initialization

+ (DMSDKEventLogger *)sharedInstance {
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
		NSNumberFormatter *currencyFormatter = [[NSNumberFormatter alloc] init];
		[currencyFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		self.currencyFormatter = currencyFormatter;
	}
	
	return self;
}

#pragma mark - Internal events

- (void)logInternalEvent:(NSString *)eventName {
	[self logInternalEvent:eventName
				parameters:nil];
}

- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters
{
	[self logInternalEvent:eventName
				parameters:parameters
			requiresCookie:NO
	   requiresFingerprint:NO
				  postData:nil];
}

- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters
				postData:(NSData *)postData
{
	[self logInternalEvent:eventName
				parameters:parameters
			requiresCookie:NO
	   requiresFingerprint:NO
				  postData:postData];
}

- (void)logInternalEvent:(NSString *)eventName
			  parameters:(NSDictionary *)parameters
		  requiresCookie:(BOOL)requiresCookie
	 requiresFingerprint:(BOOL)requiresFingerprint
				postData:(NSData *)postData
{
	//Create event
	DMSDKEvent *event = [DMSDKEvent eventWithName:eventName
									   parameters:parameters
										 postData:postData];
	
	event.requiresCookie = requiresCookie;
	event.requiresFingerprint = requiresFingerprint;
	
	[sharedEventManager logEvent:event];
}

#pragma mark - Launch events

- (void)logFirstLaunchEvent {
	DMPrettyLog
	
	//Log extra device parameters
	NSString *model = [DMSDKUIDeviceTools hwModel];
	NSString *platform = [DMSDKUIDeviceTools platform];
	NSString *os = [NSString stringWithFormat:@"%@ %@", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]];
	
	NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
	[paramsDict setValue:model forKey:@"model"];
	[paramsDict setValue:platform forKey:@"platform"];
	[paramsDict setValue:os forKey:@"os"];
	
	[self logInternalEvent:@"FirstLaunch"
				parameters:[NSDictionary dictionaryWithDictionary:paramsDict]
			requiresCookie:YES
	   requiresFingerprint:YES
				  postData:nil];
}

- (void)logTamperedLaunchEvent {
	[self logInternalEvent:@"TamperedLaunch"];
}

- (void)logReinstallLaunchEvent {
	[self logInternalEvent:@"ReinstallLaunch"];
}

- (void)logChangedIDEvent {
	NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
	[paramsDict setValue:sharedIDManager.oldUUID forKey:@"olduuid"];
	
	[self logInternalEvent:@"ChangedID"
				parameters:[NSDictionary dictionaryWithDictionary:paramsDict]];
}

#pragma mark - User Value events

- (void)logUserRegistered {
	if (![[sharedSettingsManager valueForKey:USER_REGISTERED_KEY] boolValue]) {
		[sharedSettingsManager setValue:[NSNumber numberWithBool:YES] forKey:USER_REGISTERED_KEY];
		
		[self logInternalEvent:@"UserRegistered"];
	}
}

- (void)logInAppPurchaseWithProductID:(NSString *)productID
						  priceLocale:(NSLocale *)priceLocale
								price:(double)price
							 quantity:(int)quantity
{
	//Convert the price locale to a currency
	[self.currencyFormatter setLocale:priceLocale];
	
	[self logInAppPurchaseWithProductID:productID
						   currencyCode:[self.currencyFormatter currencyCode]
								  price:price
							   quantity:quantity];
}
- (void)logInAppPurchaseWithProductID:(NSString *)productID
						 currencyCode:(NSString *)currencyCode
								price:(double)price
							 quantity:(int)quantity
{
	NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
	[paramsDict setValue:productID forKey:@"productID"];
	[paramsDict setValue:currencyCode forKey:@"currency"];
	[paramsDict setValue:[NSString stringWithFormat:@"%.2f", price] forKey:@"price"];
	[paramsDict setValue:[NSString stringWithFormat:@"%d", quantity] forKey:@"quantity"];
	
	[self logInternalEvent:@"InAppPurchase"
				parameters:[NSDictionary dictionaryWithDictionary:paramsDict]];
}

- (void)logExternalPurchaseWithProductID:(NSString *)productID
							 priceLocale:(NSLocale *)priceLocale
								   price:(double)price
								quantity:(int)quantity
{
	//Convert the price locale to a currency
	[self.currencyFormatter setLocale:priceLocale];
	
	[self logExternalPurchaseWithProductID:productID
							  currencyCode:[self.currencyFormatter currencyCode]
									 price:price
								  quantity:quantity];
}
- (void)logExternalPurchaseWithProductID:(NSString *)productID
							currencyCode:(NSString *)currencyCode
								   price:(double)price
								quantity:(int)quantity
{
	NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
	[paramsDict setValue:productID forKey:@"productID"];
	[paramsDict setValue:currencyCode forKey:@"currency"];
	[paramsDict setValue:[NSString stringWithFormat:@"%.2f", price] forKey:@"price"];
	[paramsDict setValue:[NSString stringWithFormat:@"%d", quantity] forKey:@"quantity"];
	
	[self logInternalEvent:@"ExternalPurchase"
				parameters:[NSDictionary dictionaryWithDictionary:paramsDict]];
}

- (void)logBannerClickWithPublisher:(NSString *)publisher {
	NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
	[paramsDict setValue:publisher forKey:@"publisher"];
	
	[self logInternalEvent:@"BannerClick"
				parameters:[NSDictionary dictionaryWithDictionary:paramsDict]];
}

#pragma mark - User Properties Events

- (void)logUserID:(NSString *)userID {
	if (![userID length]) {
		//Don't send an empty userID
		return;
	}
	
	if (![[sharedSettingsManager valueForKey:USER_ID_KEY] isEqualToString:userID]) {
		[sharedSettingsManager setValue:userID forKey:USER_ID_KEY];
		
		NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
		[paramsDict setValue:userID forKey:@"id"];
		
		[self logInternalEvent:@"UserID"
					parameters:[NSDictionary dictionaryWithDictionary:paramsDict]];
	}
}

@end
