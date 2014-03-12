//
//  DMSDKPasteboardManager.m
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

#import "DMSDKPasteboardManager.h"
#import "DMSDKApplicationManager.h"

#define PASTEBOARD_PREFIX			@"yMv1s7YO9nwp1ydH0pAy.XmC8XOa6ZvEBPrHpzm4w"
#define PASTEBOARD_TYPE_OWNED		@"7hVOUmmGPDYCfLXrrV5F.DyM0cleKeevbisH8EAf1"
#define PASTEBOARD_TYPE_DISTRIBUTED	@"kjniu86FUrrY76rGYOY3.hjIYwo83jc0G8u7yJuy9"
#define PASTEBOARD_DATE_KEY			@"BIli44lchy3SmytWuzlg"
#define PASTEBOARD_OWNER_KEY		@"0fjraI5J9N9kVVZKlhiM"
#define MAX_PASTEBOARDS				100
#define ENCRYPTION_KEY				@"LKLdRp93DToRUVGHhvLlRYXGwWsv38zB"

@implementation DMSDKPasteboardManager

@synthesize ownPrivatePasteboard = _ownPrivatePasteboard;
@synthesize ownProtectedPasteboard = _ownProtectedPasteboard;
@synthesize lastOtherPasteboard = _lastOtherPasteboard;
@synthesize allPasteboards = _allPasteboards;
@synthesize pasteboardLock = _pasteboardLock;
@synthesize allPasteboardLock = _allPasteboardLock;

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.ownPrivatePasteboard = nil;
	self.ownProtectedPasteboard = nil;
	self.lastOtherPasteboard = nil;
	self.allPasteboards = nil;
	self.pasteboardLock = nil;
	self.allPasteboardLock = nil;
	
	[super dealloc];
}

+ (DMSDKPasteboardManager *)sharedInstance {
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

- (id)init {
	if ((self = [super init])) {
		NSMutableArray *allPasteboards = [[NSMutableArray alloc] init];
		self.allPasteboards = allPasteboards;
		[allPasteboards release];
		
		NSLock *pasteboardLock = [[NSLock alloc] init];
		self.pasteboardLock = pasteboardLock;
		[pasteboardLock release];
		
		NSLock *allPasteboardLock = [[NSLock alloc] init];
		self.allPasteboardLock = allPasteboardLock;
		[allPasteboardLock release];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardRemoved:) name:UIPasteboardRemovedNotification object:nil];
	}
	
	return self;
}

#pragma mark - Notifications

- (void)pasteboardRemoved:(NSNotification *)notification {
	UIPasteboard *pasteboard = (UIPasteboard *)[notification object];
	
	[self.allPasteboardLock lock];
	
	[self.allPasteboards removeObject:pasteboard];
	
	[self.allPasteboardLock unlock];
}

#pragma mark - Key value

- (id)valueForKey:(NSString *)key forPasteboard:(UIPasteboard *)pasteboard {
	NSDictionary *dict = [self dictionaryForPasteboard:pasteboard];
	
	return [dict valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key forPasteboard:(UIPasteboard *)pasteboard {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryForPasteboard:pasteboard]];
	[dict setValue:value forKey:key];
	[self setDictionary:[NSDictionary dictionaryWithDictionary:dict] forPasteboard:pasteboard];
}

#pragma mark - Distributed pasteboard values

- (id)distributedValueForKey:(NSString *)key {
	id value = nil;
	
	[self.allPasteboardLock lock];
	
	for (UIPasteboard *pasteboard in self.allPasteboards) {
		NSDictionary *pasteboardDict = [self dictionaryForPasteboard:pasteboard type:PASTEBOARD_TYPE_DISTRIBUTED];
		value = [pasteboardDict valueForKey:key];
		if (value) {
			break;
		}
	}
	
	[self.allPasteboardLock unlock];
	
	return value;
}

- (void)setDistributedValue:(id)value forKey:(NSString *)key {
	[self.allPasteboardLock lock];
	
	for (UIPasteboard *pasteboard in self.allPasteboards) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryForPasteboard:pasteboard type:PASTEBOARD_TYPE_DISTRIBUTED]];
		[dict setValue:value forKey:key];
		[self setDictionary:[NSDictionary dictionaryWithDictionary:dict] forPasteboard:pasteboard type:PASTEBOARD_TYPE_DISTRIBUTED index:1];
	}
	
	[self.allPasteboardLock unlock];
}

#pragma mark - Checking methods

- (BOOL)privatePasteboardExistsForAppWithBundleID:(NSString *)bundleID {
	NSString *name = [self privatePasteboardNameForAppWithBundleID:bundleID];
	UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
	
	return (pasteboard != nil);
}

#pragma mark - Private methods

- (NSString *)privatePasteboardName {
	NSString *bundleID = [[DMSDKApplicationManager applicationBundle] bundleIdentifier];
	
	return [self privatePasteboardNameForAppWithBundleID:bundleID];
}

- (NSString *)privatePasteboardNameForAppWithBundleID:(NSString *)bundleID {
	return [DMSDKNSStringTools base64EncodeFromHexString:[DMSDKNSStringTools sha1FromString:bundleID]];
}

- (BOOL)isOwnPasteboard:(UIPasteboard *)pasteboard {
	return (pasteboard == self.ownPrivatePasteboard || pasteboard == self.ownProtectedPasteboard);
}

- (void)refreshPasteboards {
	self.ownPrivatePasteboard = nil;
	self.ownProtectedPasteboard = nil;
	self.lastOtherPasteboard = nil;
	
	//Get private pasteboard
	NSString *privatePasteboardName = [self privatePasteboardName];
	UIPasteboard *ownPrivatePasteboard = [UIPasteboard pasteboardWithName:privatePasteboardName create:NO];
	if (!ownPrivatePasteboard) {
		ownPrivatePasteboard = [UIPasteboard pasteboardWithName:privatePasteboardName create:YES];
		[ownPrivatePasteboard setPersistent:YES];
	}
	self.ownPrivatePasteboard = ownPrivatePasteboard;
	
	//Got through protected pasteboards
	int lowestUnused = -1;
	NSDate *lastDate = [NSDate distantPast];
	NSDate *firstDate = [NSDate distantFuture];
	UIPasteboard *ownPasteboard = nil;
	UIPasteboard *oldestPasteboard = nil;
	UIPasteboard *lastPasteboard = nil;
	
	for (int i=0; i < MAX_PASTEBOARDS; i++) {
		NSString *pasteboardName = [PASTEBOARD_PREFIX stringByAppendingFormat:@"-%02d", i];
		UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:NO];
		if (!pasteboard) {
			if (lowestUnused == -1) {
				lowestUnused = i;
			}
		} else {
			NSDictionary *pasteboardDict = [self dictionaryForPasteboard:pasteboard];
			if (!pasteboardDict || ![pasteboardDict isKindOfClass:[NSDictionary class]]) {
				//no dictionary, delete this pasteboard
				DMLog(@"Removing pasteboard (no dictionary): %@", pasteboardName);
				[UIPasteboard removePasteboardWithName:pasteboardName];
				if (lowestUnused == -1) {
					lowestUnused = i;
				}
			} else {
				NSString *owner = [pasteboardDict valueForKey:PASTEBOARD_OWNER_KEY];
				if (![owner length]) {
					//no owner, delete this pasteboard
					DMLog(@"Removing pasteboard (no owner): %@", pasteboardName);
					[UIPasteboard removePasteboardWithName:pasteboardName];
					if (lowestUnused == -1) {
						lowestUnused = i;
					}
				} else {
					if ([pasteboard.items count] != 2) {
						//not the correct number of items, corrupted pasteboard
						DMLog(@"Removing pasteboard (incorrect number of items): %@", pasteboardName);
						[UIPasteboard removePasteboardWithName:pasteboardName];
						if (lowestUnused == -1) {
							lowestUnused = i;
						}
					} else {
						[self.allPasteboards addObject:pasteboard];
						
						NSDate *modifiedDate = [pasteboardDict valueForKey:PASTEBOARD_DATE_KEY];
						if (modifiedDate) {
							if ([modifiedDate compare:lastDate] == NSOrderedDescending) {
								lastDate = modifiedDate;
								lastPasteboard = pasteboard;
							}
							
							if ([modifiedDate compare:firstDate] == NSOrderedAscending) {
								firstDate = modifiedDate;
								oldestPasteboard = pasteboard;
							}
						}
						
						DMLog(@"Found pasteboard: %@ (date: %@; owner: %@; events: %@)",
							  pasteboardName,
							  [pasteboardDict objectForKey:PASTEBOARD_DATE_KEY],
							  [pasteboardDict objectForKey:PASTEBOARD_OWNER_KEY],
							  [pasteboardDict objectForKey:PASTEBOARD_EVENTS_KEY]);
						
						if ([owner isEqualToString:[[DMSDKApplicationManager applicationBundle] bundleIdentifier]]) {
							ownPasteboard = pasteboard;
						}
					}
				}
			}
		}
	}
	
	if (!ownPasteboard) {
		if (lowestUnused != -1) {
			//Create a new pasteboard
			NSString *pasteboardName = [PASTEBOARD_PREFIX stringByAppendingFormat:@"-%02d", lowestUnused];
			DMLog(@"Creating a pasteboard with name: %@", pasteboardName);
			ownPasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:YES];
		} else {
			//Overwrite the oldest pasteboard
			NSString *pasteboardName = [oldestPasteboard name];
			DMLog(@"Taking ownership for pasteboard: %@", pasteboardName);
			[UIPasteboard removePasteboardWithName:pasteboardName];
			ownPasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:YES];
		}
		NSArray *items = [NSArray arrayWithObjects:
						  [NSDictionary dictionaryWithObject:[NSData data] forKey:PASTEBOARD_TYPE_OWNED],
						  [NSDictionary dictionaryWithObject:[NSData data] forKey:PASTEBOARD_TYPE_DISTRIBUTED],
						  nil];
		[ownPasteboard addItems:items];
		[ownPasteboard setPersistent:YES];
		
		[self.allPasteboards addObject:ownPasteboard];
	}
	
	self.ownProtectedPasteboard = ownPasteboard;
	self.lastOtherPasteboard = lastPasteboard;
	
	//Claim own protected pasteboard
	[self setValue:[[DMSDKApplicationManager applicationBundle] bundleIdentifier] forKey:PASTEBOARD_OWNER_KEY forPasteboard:self.ownProtectedPasteboard];
	[self setValue:[NSDate date] forKey:PASTEBOARD_DATE_KEY forPasteboard:self.ownProtectedPasteboard];
}

#pragma mark - Dictionaries

- (NSDictionary *)dictionaryForPasteboard:(UIPasteboard *)pasteboard {
	return [self dictionaryForPasteboard:pasteboard type:PASTEBOARD_TYPE_OWNED];
}

- (NSDictionary *)dictionaryForPasteboard:(UIPasteboard *)pasteboard type:(NSString *)type {
	[self.pasteboardLock lock];
	
	NSArray *dataArray = [pasteboard dataForPasteboardType:type inItemSet:nil];
	NSDictionary *pasteboardDict = nil;
	
	for (int i=0; (i < [dataArray count] && !pasteboardDict); i++) {
		NSData *pasteboardData = [dataArray objectAtIndex:i];
		@try {
			pasteboardDict = [NSKeyedUnarchiver unarchiveObjectWithData:[DMSDKNSDataTools AES256DecryptData:pasteboardData withKey:ENCRYPTION_KEY]];
		}
		@catch (NSException *exception) {
			//Invalid data
		}
	}
	
	[self.pasteboardLock unlock];
	
	return pasteboardDict;
}

- (void)setDictionary:(NSDictionary *)dictionary forPasteboard:(UIPasteboard *)pasteboard {
	if ([self isOwnPasteboard:pasteboard]) {
		[self setDictionary:dictionary forPasteboard:pasteboard type:PASTEBOARD_TYPE_OWNED index:0];
	}
}

- (void)setDictionary:(NSDictionary *)dictionary forPasteboard:(UIPasteboard *)pasteboard type:(NSString *)type index:(int)index {
	[self.pasteboardLock lock];
	
	NSData *data = [DMSDKNSDataTools AES256EncryptData:[NSKeyedArchiver archivedDataWithRootObject:dictionary] withKey:ENCRYPTION_KEY];
	NSDictionary *itemDict = [NSDictionary dictionaryWithObject:data forKey:type];
	NSMutableArray *items = [NSMutableArray arrayWithArray:pasteboard.items];
	
	if (index < [items count]) {
		[items replaceObjectAtIndex:index withObject:itemDict];
	}
	
	[pasteboard setItems:[NSArray arrayWithArray:items]];
	
	[self.pasteboardLock unlock];
}

@end
