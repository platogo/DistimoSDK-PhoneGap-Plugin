//
//  CDVDistimoSDK.m
//  Analytics
//
//  Created by Arne de Vries on 4/4/13.
//
//

#import <Cordova/CDV.h>
#import "DistimoSDK.h"

@interface CDVDistimoSDK : CDVPlugin

@end

@implementation CDVDistimoSDK

#pragma mark - Start

- (void)start:(CDVInvokedUrlCommand *)command {
	NSString *sdkKey = [command.arguments objectAtIndex:0];
	
	if (sdkKey) {
		[DistimoSDK handleLaunchWithOptions:nil
									 sdkKey:sdkKey];
		
		[self callback:CDVCommandStatus_OK
			   message:nil
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Please provide a valid SDK Key, you can create one at https://analytics.distimo.com/settings/sdk."
			   command:command];
	}
}

#pragma mark - Settings

- (void)version:(CDVInvokedUrlCommand *)command {
	NSString *version = [DistimoSDK version];
	
	if (version) {
		[self callback:CDVCommandStatus_OK
			   message:version
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Could not retrieve DistimoSDK version"
			   command:command];
	}
}

#pragma mark - User Value

- (void)logUserRegistered:(CDVInvokedUrlCommand *)command {
	[DistimoSDK logUserRegistered];
	
	[self callback:CDVCommandStatus_OK
		   message:nil
		   command:command];
}

- (void)logInAppPurchaseWithLocale:(CDVInvokedUrlCommand *)command {
	if ([command.arguments count] >= 4) {
		NSString *productID = [command.arguments objectAtIndex:0];
		NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:[command.arguments objectAtIndex:1]] autorelease];
		double price = [[command.arguments objectAtIndex:2] doubleValue];
		int quantity = [[command.arguments objectAtIndex:3] intValue];
		
		[DistimoSDK logInAppPurchaseWithProductID:productID
									  priceLocale:locale
											price:price
										 quantity:quantity];
		
		[self callback:CDVCommandStatus_OK
			   message:nil
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Not enough arguments provided"
			   command:command];
	}
}

- (void)logInAppPurchaseWithCurrency:(CDVInvokedUrlCommand *)command {
	if ([command.arguments count] >= 4) {
		NSString *productID = [command.arguments objectAtIndex:0];
		NSString *currency = [command.arguments objectAtIndex:1];
		double price = [[command.arguments objectAtIndex:2] doubleValue];
		int quantity = [[command.arguments objectAtIndex:3] intValue];
		
		[DistimoSDK logInAppPurchaseWithProductID:productID
									 currencyCode:currency
											price:price
										 quantity:quantity];
		
		[self callback:CDVCommandStatus_OK
			   message:nil
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Not enough arguments provided"
			   command:command];
	}
}

- (void)logExternalPurchaseWithLocale:(CDVInvokedUrlCommand *)command {
	if ([command.arguments count] >= 4) {
		NSString *productID = [command.arguments objectAtIndex:0];
		NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:[command.arguments objectAtIndex:1]] autorelease];
		double price = [[command.arguments objectAtIndex:2] doubleValue];
		int quantity = [[command.arguments objectAtIndex:3] intValue];
		
		[DistimoSDK logExternalPurchaseWithProductID:productID
										 priceLocale:locale
											   price:price
											quantity:quantity];
		
		[self callback:CDVCommandStatus_OK
			   message:nil
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Not enough arguments provided"
			   command:command];
	}
}

- (void)logExternalPurchaseWithCurrency:(CDVInvokedUrlCommand *)command {
	if ([command.arguments count] >= 4) {
		NSString *productID = [command.arguments objectAtIndex:0];
		NSString *currency = [command.arguments objectAtIndex:1];
		double price = [[command.arguments objectAtIndex:2] doubleValue];
		int quantity = [[command.arguments objectAtIndex:3] intValue];
		
		[DistimoSDK logExternalPurchaseWithProductID:productID
										currencyCode:currency
											   price:price
											quantity:quantity];
		
		[self callback:CDVCommandStatus_OK
			   message:nil
			   command:command];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Not enough arguments provided"
			   command:command];
	}
}

- (void)logBannerClick:(CDVInvokedUrlCommand *)command {
	NSString *publisher = [command.arguments objectAtIndex:0];
	
	[DistimoSDK logBannerClickWithPublisher:([publisher isKindOfClass:[NSNull class]] ? nil : publisher)];
	
	[self callback:CDVCommandStatus_OK
		   message:nil
		   command:command];
}

#pragma mark - User Properties

- (void)setUserID:(CDVInvokedUrlCommand *)command {
	NSString *userID = [command.arguments objectAtIndex:0];
	
	[DistimoSDK setUserID:([userID isKindOfClass:[NSNull class]] ? nil : userID)];
	
	[self callback:CDVCommandStatus_OK
		   message:nil
		   command:command];
}

#pragma mark - AppLink

- (void)openAppLink:(CDVInvokedUrlCommand *)command {
	if ([command.arguments count] >= 1) {
		NSString *applinkHandle = [command.arguments objectAtIndex:0];
		NSString *campaignHandle = [command.arguments objectAtIndex:1];
		
		[DistimoSDK openAppLink:applinkHandle
					   campaign:([campaignHandle isKindOfClass:[NSNull class]] ? nil : campaignHandle)
			   inViewController:nil];
	} else {
		[self callback:CDVCommandStatus_ERROR
			   message:@"Not enough arguments provided"
			   command:command];
	}
	
	[self callback:CDVCommandStatus_OK
		   message:nil
		   command:command];
}

#pragma mark - Helpers

- (void)callback:(CDVCommandStatus)status message:(NSString *)message command:(CDVInvokedUrlCommand *)command {
	CDVPluginResult *result;
	
	if (message) {
		result = [CDVPluginResult resultWithStatus:status
								   messageAsString:message];
	} else {
		result = [CDVPluginResult resultWithStatus:status];
	}
	
	[self.commandDelegate sendPluginResult:result
								callbackId:command.callbackId];
}

@end
