//
//  DMSDKNSDataTools.m
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

#import "DMSDKNSDataTools.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@implementation DMSDKNSDataTools

static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"; //URL_SAFE

#pragma mark - Base64

+ (NSData *)base64DecodeData:(NSData *)data {
	if (![data length]) {
		return [NSData data];
	}
	
	static char *decodingTable = NULL;
	if (decodingTable == NULL) {
		decodingTable = malloc(256);
		if (decodingTable == NULL) {
			return nil;
		}
		memset(decodingTable, CHAR_MAX, 256);
		for (int i = 0; i < 64; i++) {
			decodingTable[(short)encodingTable[i]] = i;
		}
	}
	
	const char *characters = [data bytes];
	char *bytes = malloc((([data length] + 3) / 4) * 3);
	if (bytes == NULL) {
		return nil;
	}
	
	NSUInteger length = 0;
	NSUInteger i = 0;
	while (TRUE) {
		char buffer[4];
		short bufferLength;
		for (bufferLength = 0; bufferLength < 4; i++) {
			if (characters[i] == '\0') {
				break;
			}
			if (isspace(characters[i]) || characters[i] == '=') {
				continue;
			}
			buffer[bufferLength] = decodingTable[(short)characters[i]];
			if (buffer[bufferLength++] == CHAR_MAX) {      //  Illegal character!
				free(bytes);
				return nil;
			}
		}
		
		if (bufferLength == 0) {
			break;
		}
		if (bufferLength == 1) {      //  At least two characters are needed to produce one byte!
			free(bytes);
			return nil;
		}
		
		//  Decode the characters in the buffer to bytes.
		bytes[length++] = (buffer[0] << 2) | (buffer[1] >> 4);
		if (bufferLength > 2) {
			bytes[length++] = (buffer[1] << 4) | (buffer[2] >> 2);
		}
		if (bufferLength > 3) {
			bytes[length++] = (buffer[2] << 6) | buffer[3];
		}
	}
	
	realloc(bytes, length);
	return [NSData dataWithBytesNoCopy:bytes length:length];
}

+ (NSData *)base64EncodeData:(NSData *)data {
	if([data length] == 0) {
		return [NSData data];
	}
	
    char *characters = malloc((([data length] + 2) / 3) * 4);
	if (characters == NULL) {
		return nil;
	}
	
	NSUInteger length = 0;
	NSUInteger i = 0;
	while (i < [data length]) {
		char buffer[3] = {0,0,0};
		short bufferLength = 0;
		while (bufferLength < 3 && i < [data length]) {
			buffer[bufferLength++] = ((char *)[data bytes])[i++];
		}
		
		//  Encode the bytes in the buffer to four characters, including padding "=" characters if necessary.
		characters[length++] = encodingTable[(buffer[0] & 0xFC) >> 2];
		characters[length++] = encodingTable[((buffer[0] & 0x03) << 4) | ((buffer[1] & 0xF0) >> 4)];
		if (bufferLength > 1) {
			characters[length++] = encodingTable[((buffer[1] & 0x0F) << 2) | ((buffer[2] & 0xC0) >> 6)];
		} else {
			characters[length++] = '=';
		}
		if (bufferLength > 2) {
			characters[length++] = encodingTable[buffer[2] & 0x3F];
		} else {
			characters[length++] = '=';
		}
	}
	
	return [[[NSData alloc] initWithBytes:characters length:length] autorelease];
}

+ (NSString *)base64DecodedStringFromData:(NSData *)data {
	NSData *decodedData = [DMSDKNSDataTools base64DecodeData:data];
	NSString *decodedString = [[NSString alloc] initWithBytes:[decodedData bytes] length:[decodedData length] encoding:NSUTF8StringEncoding];
	
	return [decodedString autorelease];
}

+ (NSString *)base64EncodedStringFromData:(NSData *)data {
	NSData *encodedData = [DMSDKNSDataTools base64EncodeData:data];
	NSString *encodedString = [[NSString alloc] initWithBytes:[encodedData bytes] length:[encodedData length] encoding:NSUTF8StringEncoding];
	
	return [encodedString autorelease];
}

#pragma mark - AES256

+ (NSData *)AES256EncryptData:(NSData *)data withKey:(NSString *)key {
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [data length];
	
	//See the doc: For block ciphers, the output size will always be less than or 
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesEncrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [data bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesEncrypted);
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}

+ (NSData *)AES256DecryptData:(NSData *)data withKey:(NSString *)key {
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [data length];
	
	//See the doc: For block ciphers, the output size will always be less than or 
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesDecrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [data bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesDecrypted);
	
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}

#pragma mark - Hashes

+ (NSString *)sha1FromData:(NSData *)data {
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	
	if (CC_SHA1([data bytes], [data length], digest)) {
		NSMutableString *result = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2)];
		for (int i=0; i < CC_SHA1_DIGEST_LENGTH; i++) {
			[result appendFormat:@"%02X", digest[i]];
		}
		
		return [result lowercaseString];
	}
	
	return nil;
}

+ (NSString *)md5FromData:(NSData *)data {
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	
	if (CC_MD5([data bytes], [data length], digest)) {
		NSMutableString *result = [NSMutableString stringWithCapacity:(CC_MD5_DIGEST_LENGTH * 2)];
		for (int i=0; i < CC_MD5_DIGEST_LENGTH; i++) {
			[result appendFormat:@"%02X", digest[i]];
		}
		
		return [result lowercaseString];
	}
	
	return nil;
}

@end
