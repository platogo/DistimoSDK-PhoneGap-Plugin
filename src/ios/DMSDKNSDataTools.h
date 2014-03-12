//
//  DMSDKNSDataTools.h
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

#import <Foundation/Foundation.h>

@interface DMSDKNSDataTools : NSObject

+ (NSData *)base64DecodeData:(NSData *)data;
+ (NSData *)base64EncodeData:(NSData *)data;
+ (NSString *)base64DecodedStringFromData:(NSData *)data;
+ (NSString *)base64EncodedStringFromData:(NSData *)data;

+ (NSData *)AES256EncryptData:(NSData *)data withKey:(NSString *)key;
+ (NSData *)AES256DecryptData:(NSData *)data withKey:(NSString *)key;

+ (NSString *)sha1FromData:(NSData *)data;
+ (NSString *)md5FromData:(NSData *)data;

@end
