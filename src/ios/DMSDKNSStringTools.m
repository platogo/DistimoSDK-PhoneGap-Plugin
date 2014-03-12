//
//  DMSDKNSStringTools.m
//  DistimoSDK
//
//  Created by Arne de Vries on 6/25/12.
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

#import "DMSDKNSStringTools.h"
#import "DMSDKNSDataTools.h"

@implementation DMSDKNSStringTools

#pragma mark - Base64

+ (NSString *)base64DecodeString:(NSString *)string {
	NSData *decodedData = [DMSDKNSStringTools base64DecodedDataFromString:string];
	NSString *result = [[NSString alloc] initWithBytes:[decodedData bytes] length:[decodedData length] encoding:NSUTF8StringEncoding];
	
	return [result autorelease];
}

+ (NSString *)base64EncodeString:(NSString *)string {
	NSData *encodedData = [DMSDKNSStringTools base64EncodedDataFromString:string];
	NSString *result = [[NSString alloc] initWithBytes:[encodedData bytes] length:[encodedData length] encoding:NSUTF8StringEncoding];
	
	return [result autorelease];
}

+ (NSData *)base64DecodedDataFromString:(NSString *)string {
	const char *characters = [string cStringUsingEncoding:NSASCIIStringEncoding];
	if (characters == NULL) {
		//Not an ASCII string!
		return nil;
	}
	
	NSData *data = [[NSData alloc] initWithBytes:characters length:[string length]];
	NSData *decodedData = [DMSDKNSDataTools base64DecodeData:data];
	[data release];
	
	return decodedData;
}

+ (NSData *)base64EncodedDataFromString:(NSString *)string {
	const char *characters = [string cStringUsingEncoding:NSASCIIStringEncoding];
	NSData *data = [[NSData alloc] initWithBytes:characters length:[string length]];
	NSData *encodedData = [DMSDKNSDataTools base64EncodeData:data];
	[data release];
	
	return encodedData;
}

+ (NSData *)dataFromHexString:(NSString *)string {
	if ([string length] % 2 == 0) {
		//Put bytes in bytes array
		NSMutableData *data = [NSMutableData dataWithCapacity:([string length] / 2)];
		unsigned char whole_byte;
		char byte_chars[3] = {'\0','\0','\0'};
		for (int i = 0; i < ([string length] / 2); i++) {
			byte_chars[0] = [string characterAtIndex:(i*2)];
			byte_chars[1] = [string characterAtIndex:((i*2)+1)];
			whole_byte = strtol(byte_chars, NULL, 16);
			[data appendBytes:&whole_byte length:1]; 
		}
		
		return [NSData dataWithData:data];
	}
	
	return nil;
}

+ (NSString *)base64EncodeFromHexString:(NSString *)string {
	NSData *data = [DMSDKNSStringTools dataFromHexString:string];
	NSString *encodedString = [DMSDKNSDataTools base64EncodedStringFromData:data];
	return [encodedString stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

#pragma mark - URL Encoding

+ (NSString *)urlEncodeString:(NSString *)string {
	return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
																(CFStringRef)string,
																NULL,
																(CFStringRef)@"!*'();:@&=+$,/?%#[]",
																kCFStringEncodingUTF8) autorelease];
}
+ (NSString *)urlDecodeString:(NSString *)string {
	return [(NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
																				(CFStringRef)string,
																				(CFStringRef)@"",
																				kCFStringEncodingUTF8) autorelease];
}

#pragma mark - Hashes

+ (NSString *)sha1FromString:(NSString *)string {
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	
	return [DMSDKNSDataTools sha1FromData:data];
}

+ (NSString *)md5FromString:(NSString *)string {
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	
	return [DMSDKNSDataTools md5FromData:data];
}

@end
