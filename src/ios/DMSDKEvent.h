//
//  DMSDKEvent.h
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

#import "DistimoSDK+Configuration.h"

typedef enum {
	DMSDKEventMethodURLConnection = 0,
	DMSDKEventMethodWebView
} DMSDKEventMethod;

typedef enum {
	DMSDKEventTypeInternal = 0
} DMSDKEventType;

@interface DMSDKEvent : NSObject <NSCoding> {
	NSString *_name;
	NSDictionary *_parameters;
	NSData *_postData;
	NSString *_checksum;
	NSString *_organizationID;
	NSString *_bundleID;
	NSString *_appVersion;
	NSString *_sdkVersion;
	NSDate *_timestamp;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSDictionary *parameters;
@property (nonatomic, readonly) NSData *postData;
@property (nonatomic, readonly) DMSDKEventMethod method;
@property (nonatomic, assign) DMSDKEventType type;
@property (nonatomic, assign) BOOL requiresFingerprint;
@property (nonatomic, assign) BOOL requiresCookie;

+ (DMSDKEvent *)eventWithName:(NSString *)name;
+ (DMSDKEvent *)eventWithName:(NSString *)name parameters:(NSDictionary *)parameters;
+ (DMSDKEvent *)eventWithName:(NSString *)name parameters:(NSDictionary *)parameters postData:(NSData *)postData;

- (id)initWithName:(NSString *)name;
- (id)initWithName:(NSString *)name parameters:(NSDictionary *)parameters;
- (id)initWithName:(NSString *)name parameters:(NSDictionary *)parameters postData:(NSData *)postData;

- (id)valueForKey:(NSString *)key;

- (NSString *)urlParamString;

@end
