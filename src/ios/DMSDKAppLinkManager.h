//
//  DMSDKAppLinkManager.h
//  DistimoSDK
//
//  Created by Arne de Vries on 12/20/12.
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

#import <StoreKit/StoreKit.h>
#import "DistimoSDK+Configuration.h"

#define sharedAppLinkManager [DMSDKAppLinkManager sharedInstance]

@interface DMSDKAppLinkManager : NSObject <NSURLConnectionDelegate> {
	
}

@property (nonatomic, assign) BOOL handlingConnection;
@property (nonatomic, assign) BOOL redirecting;
@property (nonatomic, retain) NSURLConnection *urlConnection;
@property (nonatomic, retain) NSURL *redirectURL;
@property (nonatomic, retain) NSTimer *redirectTimer;
@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, retain) UIViewController<SKStoreProductViewControllerDelegate> *viewController;

+ (DMSDKAppLinkManager *)sharedInstance;

- (void)openAppLink:(NSString *)applinkHandle
		   campaign:(NSString *)campaignHandle
		   uniqueID:(NSString *)uniqueID
   inViewController:(UIViewController<SKStoreProductViewControllerDelegate> *)viewController;

@end
