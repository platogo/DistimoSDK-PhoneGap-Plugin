//
//  DMSDKUIDeviceTools.m
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

#import "DMSDKUIDeviceTools.h"

#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/if.h>
#import <net/if_dl.h>

@implementation DMSDKUIDeviceTools

+ (double)systemVersionDouble {
	NSArray *systemVersionComponents = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
	if ([systemVersionComponents count] == 1) {
		return [[systemVersionComponents objectAtIndex:0] doubleValue];
	} else if ([systemVersionComponents count] >= 2) {
		return [[[systemVersionComponents subarrayWithRange:NSMakeRange(0, 2)] componentsJoinedByString:@"."] doubleValue];
	} else {
		return 0.0;
	}
}

+ (NSString *)getSysInfoByName:(char *)typeSpecifier {
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
	
    free(answer);
    return results;
}

+ (NSString *)platform {
    return [DMSDKUIDeviceTools getSysInfoByName:"hw.machine"];
}

+ (NSString *)hwModel {
    return [DMSDKUIDeviceTools getSysInfoByName:"hw.model"];
}

@end
