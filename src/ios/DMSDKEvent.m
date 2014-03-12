//
//  DMSDKEvent.m
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

#import "DMSDKEvent.h"
#import "DMSDKIDManager.h"
#import "DMSDKApplicationManager.h"

@implementation DMSDKEvent

@synthesize method = _method;
@synthesize type = _type;
@synthesize requiresFingerprint = _requiresFingerprint;
@synthesize requiresCookie = _requiresCookie;

#pragma mark - Deallocation

- (void)dealloc {
	[_name release];
	_name = nil;
	
	[_parameters release];
	_parameters = nil;
	
	[_postData release];
	_postData = nil;
	
	[_checksum release];
	_checksum = nil;
	
	[_organizationID release];
	_organizationID = nil;
	
	[_bundleID release];
	_bundleID = nil;
	
	[_appVersion release];
	_appVersion = nil;
	
	[_sdkVersion release];
	_sdkVersion = nil;
	
	[_timestamp release];
	_timestamp = nil;
	
	[super dealloc];
}

#pragma mark - Convenience methods

+ (DMSDKEvent *)eventWithName:(NSString *)name {
	return [[[DMSDKEvent alloc] initWithName:name parameters:nil] autorelease];
}
+ (DMSDKEvent *)eventWithName:(NSString *)name parameters:(NSDictionary *)parameters {
	return [[[DMSDKEvent alloc] initWithName:name parameters:parameters] autorelease];
}
+ (DMSDKEvent *)eventWithName:(NSString *)name parameters:(NSDictionary *)parameters postData:(NSData *)postData {
	return [[[DMSDKEvent alloc] initWithName:name parameters:parameters postData:postData] autorelease];
}

#pragma mark - Initialization

- (id)init {
	return [self initWithName:nil parameters:nil];
}
- (id)initWithName:(NSString *)name {
	return [self initWithName:name parameters:nil];
}
- (id)initWithName:(NSString *)name parameters:(NSDictionary *)parameters {
	return [self initWithName:name parameters:parameters postData:nil];
}
- (id)initWithName:(NSString *)name parameters:(NSDictionary *)parameters postData:(NSData *)postData {
	if (![name length]) {
		//Never return an event without a name
		return nil;
	}
	
	if ((self = [super init])) {
		_name = [name copy];
		_parameters = [[NSDictionary alloc] initWithDictionary:parameters];
		_postData = [[NSData alloc] initWithData:postData];
		
		_organizationID = [[sharedIDManager organizationID] retain];
		_bundleID = [[[DMSDKApplicationManager applicationBundle] bundleIdentifier] copy];
		_appVersion = [[[DMSDKApplicationManager applicationBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] copy];
		_sdkVersion = [VERSION copy];
		_timestamp = [[NSDate alloc] init];
		
		[self calculateChecksum];
	}
	
	return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super init])) {
		_name = [[aDecoder decodeObjectForKey:@"name"] copy];
		_parameters = [[NSDictionary alloc] initWithDictionary:[aDecoder decodeObjectForKey:@"parameters"]];
		_postData = [[NSData alloc] initWithData:[aDecoder decodeObjectForKey:@"postData"]];
		
		_requiresCookie = [aDecoder decodeBoolForKey:@"requiresCookie"];
		_requiresFingerprint = [aDecoder decodeBoolForKey:@"requiresFingerprint"];
		_type = [aDecoder decodeIntForKey:@"type"];
		
		_checksum = [[aDecoder decodeObjectForKey:@"checksum"] copy];
		_organizationID = [[aDecoder decodeObjectForKey:@"organizationID"] copy];
		_bundleID = [[aDecoder decodeObjectForKey:@"bundleID"] copy];
		_appVersion = [[aDecoder decodeObjectForKey:@"appVersion"] copy];
		_timestamp = [[aDecoder decodeObjectForKey:@"timestamp"] retain];
		_sdkVersion = [[aDecoder decodeObjectForKey:@"sdkVersion"] copy];
		
		//Make sure the sdk version is set (legacy)
		if (![_sdkVersion length]) {
			_sdkVersion = [VERSION copy];
			
			//Recalculate the checksum
			[self calculateChecksum];
		}
	}
	
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_name forKey:@"name"];
	[aCoder encodeObject:_parameters forKey:@"parameters"];
	[aCoder encodeObject:_postData forKey:@"postData"];
	
	[aCoder encodeBool:_requiresCookie forKey:@"requiresCookie"];
	[aCoder encodeBool:_requiresFingerprint forKey:@"requiresFingerprint"];
	[aCoder encodeInt:_type forKey:@"type"];
	
	[aCoder encodeObject:_checksum forKey:@"checksum"];
	[aCoder encodeObject:_organizationID forKey:@"organizationID"];
	[aCoder encodeObject:_bundleID forKey:@"bundleID"];
	[aCoder encodeObject:_appVersion forKey:@"appVersion"];
	[aCoder encodeObject:_sdkVersion forKey:@"sdkVerion"];
	[aCoder encodeObject:_timestamp forKey:@"timestamp"];
}

#pragma mark - Key Value

- (id)valueForKey:(NSString *)key {
	return [_parameters valueForKey:key];
}

#pragma mark - Properties

- (NSString *)name {
	return [NSString stringWithString:_name];
}
- (NSDictionary *)parameters {
	return [NSDictionary dictionaryWithDictionary:_parameters];
}
- (NSData *)postData {
	return [NSData dataWithData:_postData];
}
- (DMSDKEventMethod)method {
	if (self.requiresCookie || self.requiresFingerprint) {
		return DMSDKEventMethodWebView;
	} else {
		return DMSDKEventMethodURLConnection;
	}
}

- (void)setRequiresCookie:(BOOL)requiresCookie {
	if (_requiresCookie != requiresCookie) {
		_requiresCookie = requiresCookie;
		
		//Recalculate the checksum
		[self calculateChecksum];
	}
}

- (void)setRequiresFingerprint:(BOOL)requiresFingerprint {
	if (_requiresFingerprint != requiresFingerprint) {
		_requiresFingerprint = requiresFingerprint;
		
		//Recalculate the checksum
		[self calculateChecksum];
	}
}

- (void)setType:(DMSDKEventType)type {
	if (_type != type) {
		_type = type;
		
		//Recalculate the checksum
		[self calculateChecksum];
	}
}

#pragma mark - Private methods

- (void)calculateChecksum {
	[_checksum release];
	
	NSString *payload = [DMSDKNSStringTools md5FromString:[self urlParamPayload]];
	if ([_postData length]) {
		NSString *postMD5 = [DMSDKNSDataTools md5FromData:_postData];
		payload = [DMSDKNSStringTools md5FromString:[NSString stringWithFormat:@"%@%@", payload, postMD5]];
	}
	NSString *signingKey = [sharedIDManager signingKey];
	
	NSString *input = [NSString stringWithFormat:@"%@%@", payload, signingKey];
	_checksum = [[DMSDKNSStringTools md5FromString:input] copy];
}

- (NSString *)fullTypeString {
	return (self.type == DMSDKEventTypeInternal ? @"Internal" : @"");
}
- (NSString *)parameterString {
	if ([_parameters count]) {
		NSMutableArray *keyValueArray = [NSMutableArray arrayWithCapacity:[_parameters count]];
		for (NSString *key in [_parameters allKeys]) {
			NSString *value = [_parameters valueForKey:key];
			NSString *keyValue = [NSString stringWithFormat:@"%@=%@", [DMSDKNSStringTools urlEncodeString:key], [DMSDKNSStringTools urlEncodeString:value]];
			[keyValueArray addObject:keyValue];
		}
		
		return [keyValueArray componentsJoinedByString:@";"];
	}
	
	return @"";
}

#pragma mark - Strings and Data

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ Event: %@ %@", [self fullTypeString], _name, ([_parameters count] ? _parameters : @"{ }")];
}
- (NSString *)urlParamString {
	return [[self urlParamPayload] stringByAppendingFormat:@"&ct=%.0f&cs=%@", ([[NSDate date] timeIntervalSince1970] * 1000), _checksum];
}
- (NSString *)urlParamPayload {
	NSMutableString *result = [NSMutableString stringWithFormat:@"en=%@", _name];
	if (_requiresCookie) {
		[result appendString:@"&sc=1"];
	}
	if (_requiresFingerprint) {
		[result appendString:@"&gh=1"];
	}
	[result appendFormat:@"&lt=%.0f", ([_timestamp timeIntervalSince1970] * 1000)];
	[result appendFormat:@"&oi=%@", _organizationID];
	[result appendFormat:@"&bu=%@", _bundleID];
	[result appendFormat:@"&av=%@", _appVersion];
	[result appendFormat:@"&sv=%@", _sdkVersion];
	[result appendFormat:@"&uu=%@", [sharedIDManager UUID]];
	[result appendString:@"&es=i"];
	[result appendFormat:@"&ep=%@", [DMSDKNSStringTools urlEncodeString:[self parameterString]]];
	
	return [NSString stringWithString:result];
}

@end
