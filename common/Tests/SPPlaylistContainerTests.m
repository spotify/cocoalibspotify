//
//  SPPlaylistContainerTests.m
//  CocoaLibSpotify iOS Library
//
//  Created by Kyle Fleming on 6/22/12.
/*
 Copyright (c) 2012, Spotify AB
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of Spotify AB nor the names of its contributors may 
 be used to endorse or promote products derived from this software 
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL SPOTIFY AB BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SPPlaylistContainerTests.h"
#import "SPSession.h"
#import "SPPlaylistContainer.h"
#include "appkey.c"

static NSString * const kTestUserNameUserDefaultsKey1 = @"TestUserName";
static NSString * const kTestPasswordUserDefaultsKey1 = @"TestPassword";

@interface SPPlaylistContainerTests ()
@end

@implementation SPPlaylistContainerTests

-(void)test1PlaylistContainer {
	[SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:g_appkey length:g_appkey_size]
											   userAgent:@"com.spotify.CocoaLSUnitTests2"
										   loadingPolicy:SPAsyncLoadingManual
												   error:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loginDidSucceed:)
												 name:SPSessionLoginDidSucceedNotification
											   object:nil];
	
	NSString *userName = [[NSUserDefaults standardUserDefaults] valueForKey:kTestUserNameUserDefaultsKey1];
	NSString *password = [[NSUserDefaults standardUserDefaults] valueForKey:kTestPasswordUserDefaultsKey1];
	[[SPSession sharedSession] attemptLoginWithUserName:userName
											   password:password
									rememberCredentials:NO];
}

-(void)loginDidSucceed:(NSNotification *)notification {
//	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session then:^(NSArray *loadedSession) {
		
		SPPlaylistContainer *container = session.userPlaylists;
		SPTestAssert(container != nil, @"User playlists is nil");
		
		[SPAsyncLoading waitUntilLoaded:container then:^(NSArray *loadedItems) {
			SPTestAssert(container.loaded == YES, @"userPlaylists not loaded");
			SPTestAssert(container.flattenedPlaylists.count > 0, @"No playlists loaded");
			[self passTest:@selector(test1PlaylistContainer)];
		}];
	}];
}


@end
