//
//  DMSDKSettingsManager.m
//  DistimoSDK
//
//  Created by Arne de Vries on 5/21/12.
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

#import "DMSDKSettingsManager.h"
#import "DMSDKPasteboardManager.h"

@implementation DMSDKSettingsManager

- (void)dealloc {
	
	[super dealloc];
}

+ (DMSDKSettingsManager *)sharedInstance {
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
		
	}
	
	return self;
}

#pragma mark - Key/value methods

- (id)valueForKey:(NSString *)key {
	return [self valueForKey:key forType:DMSDKSettingsTypeDefaults];
}
- (id)valueForKey:(NSString *)key forType:(DMSDKSettingsType)type {
	return [[self dictionaryForType:type] valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
	[self setValue:value forKey:key forType:DMSDKSettingsTypeDefaults];
}
- (void)setValue:(id)value forKey:(NSString *)key forType:(DMSDKSettingsType)type {
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryForType:type]];
	if (value) {
		[newDict setValue:value forKey:key];
	} else {
		[newDict removeObjectForKey:key];
	}
	[self setDictionary:[NSDictionary dictionaryWithDictionary:newDict] forType:type];
}

#pragma mark - Private methods

- (NSDictionary *)dictionaryForType:(DMSDKSettingsType)type {
	NSData *encryptedData = nil;
	
	if (type == DMSDKSettingsTypeDefaults) {
		encryptedData = [(NSData *)CFPreferencesCopyAppValue((CFStringRef)ENCRYPTED_DATA_KEY, kCFPreferencesCurrentApplication) autorelease];
	} else if (type == DMSDKSettingsTypeKeychain) {
		encryptedData = [self keychainValueForKey:ENCRYPTED_DATA_KEY];
	} else if (type == DMSDKSettingsTypePasteboard) {
		encryptedData = [sharedPasteboardManager distributedValueForKey:ENCRYPTED_DATA_KEY];
	}
	
	NSDictionary *result = nil;
	
	if ([encryptedData length]) {
		@try {
			NSData *encodedData = [DMSDKNSDataTools AES256DecryptData:encryptedData withKey:ENCRYPTION_KEY];
			result = [NSKeyedUnarchiver unarchiveObjectWithData:encodedData];
		}
		@catch (NSException *exception) {
			//Decoding didn't work, corrupted data?
		}
	}
	
	return result;
}

- (void)setDictionary:(NSDictionary *)dictionary forType:(DMSDKSettingsType)type {
	NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
	NSData *encryptedData = [DMSDKNSDataTools AES256EncryptData:encodedData withKey:ENCRYPTION_KEY];
	
	if (type == DMSDKSettingsTypeDefaults) {
		CFPreferencesSetAppValue((CFStringRef)ENCRYPTED_DATA_KEY, encryptedData, kCFPreferencesCurrentApplication);
		CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
	} else if (type == DMSDKSettingsTypeKeychain) {
		[self setKeychainValue:encryptedData forKey:ENCRYPTED_DATA_KEY];
	} else if (type == DMSDKSettingsTypePasteboard) {
		[sharedPasteboardManager setDistributedValue:encryptedData forKey:ENCRYPTED_DATA_KEY];
	}
}

#pragma mark - Keychain methods

- (id)keychainValueForKey:(NSString *)key {
	NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
						   (NSString *)kSecClassGenericPassword, (NSString *)kSecClass,
						   key, kSecAttrAccount,
						   kCFBooleanTrue, kSecReturnAttributes, nil];
	
	NSDictionary *result;
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
	if (status != noErr) {
		return nil;
	} else {
		id value = [[[result objectForKey:(NSString *)kSecAttrGeneric] retain] autorelease];
		[result release];
		return value;
	}
}

- (void)setKeychainValue:(id)value forKey:(NSString *)key {
	OSStatus status;
	
	//Check if a value already exists for this key
	NSString *existingValue = [self keychainValueForKey:key];
	
	if (existingValue) {
		//Value already exists, update it
		NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
							   (NSString *)kSecClassGenericPassword, (NSString *)kSecClass,
							   key, kSecAttrAccount, nil];
		NSDictionary *attributesToUpdate = [NSDictionary dictionaryWithObject:value forKey:(NSString *)kSecAttrGeneric];
		status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributesToUpdate);
	} else {
		// Value does not exist, add it
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
									(NSString *)kSecClassGenericPassword, (NSString *)kSecClass,
									key, kSecAttrAccount,
									value, kSecAttrGeneric, nil];
		status = SecItemAdd((CFDictionaryRef)attributes, NULL);
	}
	
	if (status != noErr) {
		DMLog(@"Error storing secure value: %d", (int)status);
	}
}

@end
