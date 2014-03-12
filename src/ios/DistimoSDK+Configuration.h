//
//  DistimoSDK+Configuration.h
//  DistimoSDK
//
//  Created by Arne de Vries on 12/31/13.
//  Copyright (c) 2013 Distimo. All rights reserved.
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

#pragma mark - Imports

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DMSDKTools.h"



#pragma mark - Constants

#define VERSION						@"2.6"
#define USER_AGENT_SUFFIX			[NSString stringWithFormat:@"DistimoSDK/%@", VERSION]
#define EVENT_URL					@"https://a.distimo.mobi/e/"
#define APPLINK_HOST				@"app.lk"

#define DMApplicationDidBecomeActiveNotification	@"DMApplicationDidBecomeActiveNotification"
#define DMApplicationWillResignActiveNotification	@"DMApplicationWillResignActiveNotification"
#define DMApplicationDidEnterBackgroundNotification	@"DMApplicationDidEnterBackgroundNotification"
#define DMApplicationCrashedNotification			@"DMApplicationCrashedNotification"



#pragma mark - Macros

#define dispatch_safe_sync(queue, block)			if (dispatch_get_current_queue() == queue) { block(); } else { dispatch_sync(queue, block); }



#pragma mark - Logging

//Define your own logging directive here if you want to enable debug logging (e.g. NSLog(...))
#define DMLog(...)

#define DMPrettyLog					DMLog();
#define DMPrettyMethod				[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__]



