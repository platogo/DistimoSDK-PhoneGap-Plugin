//
//  DMSDKIDManager.h
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

#define sharedIDManager [DMSDKIDManager sharedInstance]

#define UUID_KEY		@"fZEgwunWg64UDmewRzeb"

@interface DMSDKIDManager : NSObject {
	
}

@property (nonatomic, readonly) NSString *UUID;
@property (nonatomic, readonly) NSString *oldUUID;
@property (nonatomic, readonly) NSString *organizationID;
@property (nonatomic, readonly) NSString *signingKey;

+ (DMSDKIDManager *)sharedInstance;
+ (BOOL)setSDKKey:(NSString *)sdkKey;

@end
