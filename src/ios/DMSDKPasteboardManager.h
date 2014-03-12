//
//  DMSDKPasteboardManager.h
//  DistimoSDK
//
//  Created by Arne de Vries on 5/11/12.
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

#define sharedPasteboardManager [DMSDKPasteboardManager sharedInstance]

#define PASTEBOARD_EVENTS_KEY	@"yELjzcus2oDJVVYOKveI"

@interface DMSDKPasteboardManager : NSObject {
	
}

@property (nonatomic, retain) UIPasteboard *ownPrivatePasteboard;
@property (nonatomic, retain) UIPasteboard *ownProtectedPasteboard;
@property (nonatomic, retain) UIPasteboard *lastOtherPasteboard;
@property (nonatomic, retain) NSMutableArray *allPasteboards;
@property (nonatomic, retain) NSLock *pasteboardLock;
@property (nonatomic, retain) NSLock *allPasteboardLock;

+ (DMSDKPasteboardManager *)sharedInstance;

- (void)refreshPasteboards;

- (id)valueForKey:(NSString *)key forPasteboard:(UIPasteboard *)pasteboard;
- (void)setValue:(id)value forKey:(NSString *)key forPasteboard:(UIPasteboard *)pasteboard;

- (id)distributedValueForKey:(NSString *)key;
- (void)setDistributedValue:(id)value forKey:(NSString *)key;

- (BOOL)privatePasteboardExistsForAppWithBundleID:(NSString *)bundleID;

@end
