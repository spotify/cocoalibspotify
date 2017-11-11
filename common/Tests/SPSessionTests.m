//
//  SPSessionTests.m
//  CocoaLibSpotify Mac Framework
//
//  Created by Daniel Kennett on 09/05/2012.
/*
 Copyright (c) 2011, Spotify AB
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

#import "SPSessionTests.h"
#import "SPSession.h"
#import "SPUser.h"
#import "TestConstants.h"
#import "NSData+Base64.h"

@implementation SPSessionTests {
	BOOL _didGetLoginBlob;
	BOOL _shouldValidateBlobs;
	NSString *_loginBlobUsername;
	NSString *_loginBlob;
}

#pragma mark - Initialising SPSession

-(void)test1InvalidSessionInit {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
    NSError *error = nil;
    [SPSession initializeSharedSessionWithApplicationKey:nil
                                               userAgent:@"com.spotify.CocoaLSUnitTests"
                                           loadingPolicy:SPAsyncLoadingManual
                                                   error:&error];

    SPTestAssert(error != nil, @"Session initialisation should have provided an error.");
    SPTestAssert([SPSession sharedSession] == nil, @"Session should be nil: %@", [SPSession sharedSession]);

    error = nil;
    [SPSession initializeSharedSessionWithApplicationKey:nil
                                               userAgent:@""
                                           loadingPolicy:SPAsyncLoadingManual
                                                   error:&error];

    SPTestAssert(error != nil, @"Session initialisation should have provided an error.");
    SPTestAssert([SPSession sharedSession] == nil, @"Session should be nil: %@", [SPSession sharedSession]);
    SPPassTest();
}

-(void)test2ValidSessionInit {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);

	NSString *base64AppKeyString = [[NSUserDefaults standardUserDefaults] stringForKey:kAppKeyUserDefaultsKey];
	SPTestAssert(base64AppKeyString.length != 0, @"Appkey cannot be empty.");
	NSData *appKey = [NSData dataFromBase64String:base64AppKeyString];
	SPTestAssert(appKey.length != 0, @"Appket is invalid.");

	NSError *error = nil;
    [SPSession initializeSharedSessionWithApplicationKey:appKey
                                               userAgent:@"com.spotify.CocoaLSUnitTests"
                                           loadingPolicy:SPAsyncLoadingManual
                                                   error:&error];

    SPTestAssert(error == nil, @"Error should be nil: %@.", error);
    SPTestAssert([SPSession sharedSession] != nil, @"Session should not be be nil.");

    [SPSession sharedSession].delegate = self;

    [[SPSession sharedSession] fetchLoginUserName:^(NSString *loginUserName) {
        SPTestAssert(loginUserName == nil, @"loginUserName should be nil: %@.", loginUserName);
        SPPassTest();
    }];
}

#pragma mark - Logging In

-(void)test3SessionLogin {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	SPTestAssert([SPSession sharedSession] != nil, @"Session should not be be nil.");
	
	NSString *userName = [[NSUserDefaults standardUserDefaults] valueForKey:kTestUserNameUserDefaultsKey];
	NSString *password = [[NSUserDefaults standardUserDefaults] valueForKey:kTestPasswordUserDefaultsKey];
	
	SPTestAssert(userName.length > 0, @"Test username is nil.");
	SPTestAssert(password.length > 0, @"Test password is nil.");
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loginDidSucceed:)
												 name:SPSessionLoginDidSucceedNotification
                                             object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(loginDidFail:)
                                               name:SPSessionLoginDidFailNotification
                                             object:nil];
	
	[[SPSession sharedSession] attemptLoginWithUserName:userName
                                             password:password];
}

-(void)loginDidSucceed:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[[SPSession sharedSession] fetchLoginUserName:^(NSString *loginUserName) {
		SPOtherTestAssert(@selector(test3SessionLogin), loginUserName != nil, @"loginUserName was nil after login");
		[self passTest:@selector(test3SessionLogin)];
	}];
}

-(void)loginDidFail:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self failTest:@selector(test3SessionLogin) format:@"Login failed: %@", [[notification userInfo] valueForKey:SPSessionLoginDidFailErrorKey]];
}

#pragma mark - Misc

-(void)test4UserDetails {

	SPAssertTestCompletesInTimeInterval(kSPAsyncLoadingDefaultTimeout * 2);
	SPTestAssert([SPSession sharedSession] != nil, @"Session should not be be nil.");
	
	[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		
		SPTestAssert([NSThread isMainThread], @"SPAsyncLoading callback on wrong queue.");
		SPTestAssert(notLoadedItems.count == 0, @"Session loading timed out for %@", [SPSession sharedSession]);
		
		[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].user timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedUsers, NSArray *notLoadedUsers) {
			
			SPTestAssert(notLoadedUsers.count == 0, @"User loading timed out for %@", [SPSession sharedSession].user);
			
			SPUser *user = [SPSession sharedSession].user;
			SPTestAssert(user.canonicalName.length > 0, @"User has no canonical name: %@", user);
			SPTestAssert(user.displayName.length > 0, @"User has no display name: %@", user);
			SPTestAssert(user.spotifyURL != nil, @"User has no Spotify URI: %@", user);
			SPPassTest();
		}];
	}];
}

-(void)test5SessionLocale {

	SPAssertTestCompletesInTimeInterval(kSPAsyncLoadingDefaultTimeout);
	SPTestAssert([SPSession sharedSession] != nil, @"Session should not be be nil.");
	
	[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		
		SPTestAssert(notLoadedItems.count == 0, @"Session loading timed out for %@", [SPSession sharedSession]);
		SPTestAssert([SPSession sharedSession].locale != nil, @"Session has no locale.");
		SPPassTest();
	}];
}

-(void)test6CredentialBlobs {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	_shouldValidateBlobs = YES;
	
	if (_didGetLoginBlob)
		[self validateReceivedBlobs];
}

-(void)validateReceivedBlobs {
	[SPSession sharedSession].delegate = nil;
	
	SEL selector = @selector(test6CredentialBlobs);
	NSString *userName = [[NSUserDefaults standardUserDefaults] valueForKey:kTestUserNameUserDefaultsKey];
	
	SPOtherTestAssert(selector, [_loginBlobUsername caseInsensitiveCompare:userName] == NSOrderedSame, @"Got incorrect user for blob: %@", _loginBlobUsername);
	SPOtherTestAssert(selector, _loginBlob.length > 0, @"Got empty login blob");
	[self passTest:selector];
}

-(void)session:(SPSession *)session didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName {
	_loginBlobUsername = userName;
	_loginBlob = credential;
	_didGetLoginBlob = YES;
	if (_shouldValidateBlobs)
		[self validateReceivedBlobs];
}

@end
