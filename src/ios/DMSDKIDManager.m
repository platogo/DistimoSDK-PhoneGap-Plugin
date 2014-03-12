//
//  DMSDKIDManager.m
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

#import "DMSDKIDManager.h"
#import "DMSDKSettingsManager.h"
#import "DMSDKPasteboardManager.h"

@implementation DMSDKIDManager

@synthesize UUID = _uuid;
@synthesize oldUUID	= _oldUUID;

static NSString *_organizationID = nil;
static NSString *_signingKey = nil;

#pragma mark - Deallocation

- (void)dealloc {
	[_uuid release];
	_uuid = nil;
	
	[_oldUUID release];
	_oldUUID = nil;
	
	[_organizationID release];
	_organizationID = nil;
	
	[_signingKey release];
	_signingKey = nil;
	
	[super dealloc];
}

#pragma mark - Initialization

+ (DMSDKIDManager *)sharedInstance {
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
		_uuid = [[self getUUID] copy];
	}
	
	return self;
}

#pragma mark - Public methods

+ (BOOL)setSDKKey:(NSString *)sdkKey {
	if ([sdkKey length] <= 12) {
		return NO;
	}

	//Last 12 characters is signing key
	int splitIndex = ([sdkKey length] - 12);
	
	[_organizationID release];
	_organizationID = [[sdkKey substringToIndex:splitIndex] retain];
	
	[_signingKey release];
	_signingKey = [[sdkKey substringFromIndex:splitIndex] retain];
	
	return YES;
}

- (NSString *)signingKey {
	return ([_signingKey length] ? [NSString stringWithString:_signingKey] : @"");
}

- (NSString *)organizationID {
	return ([_organizationID length] ? [NSString stringWithString:_organizationID] : @"");
}

#pragma mark - Private methods

- (NSString *)getUUID {
	//Try to get stored UUID from the pasteboard
	NSString *uuid = [self getUUIDFromPasteboard];
	
	if (![uuid length]) {
		//Try to get UUID the keychain (could be left from previous install)
		uuid = [self getUUIDFromKeychain];
		
		if (!uuid) {
			//No UUID found, generate a new one (will be stored in pasteboard and keychain further down)
			uuid = [self getRandomUUID];
		}
	}
	
	//Check with previously stored UUID in the keychain
	NSString *oldUUID = [self getUUIDFromKeychain];
	
	if ([oldUUID length] && ![oldUUID isEqualToString:uuid]) {
		//The UUID has changed
		_oldUUID = [oldUUID copy];
	}
	
	//Store the UUID in the pasteboard
	[sharedPasteboardManager setValue:uuid forKey:UUID_KEY forPasteboard:sharedPasteboardManager.ownProtectedPasteboard];
	
	//Store the UUID in the keychain to survive reinstalling
	[sharedSettingsManager setValue:uuid forKey:UUID_KEY forType:DMSDKSettingsTypeKeychain];
	
	return uuid;
}

- (NSString *)getUUIDFromPasteboard {
	return [sharedPasteboardManager valueForKey:UUID_KEY forPasteboard:sharedPasteboardManager.lastOtherPasteboard];
}

- (NSString *)getUUIDFromKeychain {
	return (NSString *)[sharedSettingsManager valueForKey:UUID_KEY forType:DMSDKSettingsTypeKeychain];
}

- (NSString *)getRandomUUID {
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	NSString *uuidString = [[(NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	CFRelease(uuid);
	
	return [DMSDKNSStringTools base64EncodeFromHexString:uuidString];
}

@end
