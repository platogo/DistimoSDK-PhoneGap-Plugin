//
//  DMSDKEventManager.h
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

#define sharedEventManager [DMSDKEventManager sharedInstance]

@class DMSDKEvent;

@interface DMSDKEventManager : NSObject <UIWebViewDelegate, NSURLConnectionDelegate> {
	
}

@property (nonatomic, retain) NSMutableArray *eventQueue;
@property (nonatomic, retain) NSLock *storeLock;

@property (nonatomic, retain) NSURLConnection *urlConnection;
@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, retain) DMSDKEvent *currentEvent;

@property (nonatomic, assign) BOOL backgroundConnectivityEnabled;
@property (nonatomic, assign) BOOL didEnterBackground;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic, retain) NSTimer *backgroundTimer;

+ (DMSDKEventManager *)sharedInstance;

- (void)logEvent:(DMSDKEvent *)event;

@end
