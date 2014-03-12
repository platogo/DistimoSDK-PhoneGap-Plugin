//
//  DMSDKApplicationManager.m
//  DistimoSDK
//
//  Created by Arne de Vries on 5/14/12.
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

#import "DMSDKApplicationManager.h"
#import "DMSDKSettingsManager.h"
#import "DMSDKEventLogger.h"
#import "DMSDKIDManager.h"

#define EXCEPTION_KEY	@"B50uzRDaoyDX8QED9UPH"

@implementation DMSDKApplicationManager

@synthesize applicationState = _applicationState;

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

+ (DMSDKApplicationManager *)sharedInstance {
	static id _sharedInstance = nil;
	
	if (!_sharedInstance) {
		@synchronized (self) {
			if (!_sharedInstance) {
				_sharedInstance = [[self alloc] init];
			}
		}
	}
	
	return _sharedInstance;
}

+ (NSBundle *)applicationBundle {
	static NSBundle *_applicationBundle = nil;
	
	if (!_applicationBundle) {
		@synchronized(self) {
			if (!_applicationBundle) {
				Class class = [[UIApplication sharedApplication].delegate class];
				_applicationBundle = [[NSBundle bundleForClass:class] retain];
				
				//Use the mainBundle as a fallback, should not be necessary but just in case
				if (!_applicationBundle) {
					_applicationBundle = [[NSBundle mainBundle] retain];
				}
			}
		}
	}
	
	return _applicationBundle;
}

- (id)init {
	if ((self = [super init])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
		
		//Check for an already active application (for plugins that do not start the SDK on didFinishLaunching)
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			[self applicationDidBecomeActive:nil];
		}
	}
	
	return self;
}

#pragma mark - UncaughtExceptionHandler

static NSUncaughtExceptionHandler *otherUncaughtExceptionHandler = NULL;

static void uncaughtExceptionHandler(NSException *exception) {
	DMLog(@"%@", [exception callStackSymbols]);
	
	NSArray *callStackSymbols = [exception callStackSymbols];
	for (NSString *callStackSymbol in callStackSymbols) {
		if ([callStackSymbol rangeOfString:@"[DMSDK"].location != NSNotFound || [callStackSymbol rangeOfString:@"[DistimoSDK"].location != NSNotFound) {
			//DistimoSDK crash, add crash information
			NSArray *exceptionInfo = [NSArray arrayWithObjects:
									  [NSString stringWithFormat:@"name: %@", [exception name]],
									  [NSString stringWithFormat:@"reason: %@", [exception reason]],
									  [NSString stringWithFormat:@"userInfo: %@", [exception userInfo]],
									  nil];
			
			//Store the callstack symbols together with the information in the NSUserDefaults
			[sharedSettingsManager setValue:[callStackSymbols arrayByAddingObjectsFromArray:exceptionInfo]
									 forKey:EXCEPTION_KEY
									forType:DMSDKSettingsTypeDefaults];
			
			break;
		}
	}
	
	//Call the next exception handler
	if (otherUncaughtExceptionHandler) {
		otherUncaughtExceptionHandler(exception);
	}
}

- (void)startUncaughtExceptionHandler {
	NSArray *callStackSymbols = [sharedSettingsManager valueForKey:EXCEPTION_KEY forType:DMSDKSettingsTypeDefaults];
	if (callStackSymbols) {
		//Send exception event
		[sharedEventLogger logInternalEvent:@"DistimoException" parameters:nil postData:[[callStackSymbols componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		
		//Clear the exception
		[sharedSettingsManager setValue:nil forKey:EXCEPTION_KEY forType:DMSDKSettingsTypeDefaults];
	}
	
	otherUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
	NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
}

#pragma mark - Methods

- (void)handleApplicationLaunch {
	//We store a random value in the keychain and in the user defaults. The value in the keychain will survive
	//app reinstalls, the value in the user defaults doesn't.
	
	//Read keychain value
	NSString *keychainAUID = [sharedSettingsManager valueForKey:AUID_KEY forType:DMSDKSettingsTypeKeychain];
	
	if ([keychainAUID length]) {
		//Read user defaults value
		NSString *defaultsAUID = [sharedSettingsManager valueForKey:AUID_KEY forType:DMSDKSettingsTypeDefaults];
		
		if ([defaultsAUID length]) {
			if ([keychainAUID isEqualToString:defaultsAUID]) {
				//Keys are the same, normal launch, do nothing
				
			} else {
				//Keys are different, tampered!
				[sharedEventLogger logTamperedLaunchEvent];
				
				//Store keychain AUID in defaults
				[sharedSettingsManager setValue:keychainAUID forKey:AUID_KEY forType:DMSDKSettingsTypeDefaults];
			}
		} else {
			//No AUID in the defaults, reinstall
			[sharedEventLogger logReinstallLaunchEvent];
			
			//Store keychain AUID in defaults
			[sharedSettingsManager setValue:keychainAUID forKey:AUID_KEY forType:DMSDKSettingsTypeDefaults];
		}
	} else {
		//No AUID in keychain, first launch
		[sharedEventLogger logFirstLaunchEvent];
		
		//Store new AUID in keychain and defaults
		NSString *auid = [self randomAUID];
		
		[sharedSettingsManager setValue:auid forKey:AUID_KEY forType:DMSDKSettingsTypeKeychain];
		[sharedSettingsManager setValue:auid forKey:AUID_KEY forType:DMSDKSettingsTypeDefaults];
	}
    
    //Check for old UUID and send changedID event
    if ([sharedIDManager.oldUUID length]) {
        [sharedEventLogger logChangedIDEvent];
    }
}

- (NSString *)randomAUID {
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	NSString *uuidString = [[(NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	CFRelease(uuid);
	
	return [DMSDKNSStringTools base64EncodeFromHexString:uuidString];
}

#pragma mark - Notifications

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateDidFinishLaunching;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateActive;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DMApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateInactive;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DMApplicationWillResignActiveNotification object:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateToForeground;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateInBackground;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DMApplicationDidEnterBackgroundNotification object:nil];
}

- (void)applicationWillTerminate:(NSNotificationCenter *)notification {
	DMPrettyLog
	
	self.applicationState = DMApplicationStateTerminating;
}

@end
