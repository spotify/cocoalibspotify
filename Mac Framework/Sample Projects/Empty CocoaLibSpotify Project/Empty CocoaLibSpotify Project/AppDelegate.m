//
//  AppDelegate.m
//  Empty CocoaLibSpotify Project
//
//  Created by Daniel Kennett on 02/08/2012.
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

/*
 This project is a simple project that does nothing but set up a basic CocoaLibSpotify
 application. This can be used to quickly get started with a new project that uses CocoaLibSpotify.
 */

#import "AppDelegate.h"
#import <CocoaLibSpotify/CocoaLibSpotify.h>

#define SP_LIBSPOTIFY_DEBUG_LOGGING 0

#error Please get an appkey.c file from developer.spotify.com and remove this error before building.
#include "appkey.c"

@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	NSString *userAgent = [[[NSBundle mainBundle] infoDictionary] valueForKey:(__bridge NSString *)kCFBundleIdentifierKey];
	NSData *appKey = [NSData dataWithBytes:&g_appkey length:g_appkey_size];

	[SPSession createSharedSessionWithKey:appKey
								userAgent:userAgent
							loadingPolicy:SPAsyncLoadingManual
								 callback:^(SPSession *sharedSession, NSError *error) {
									 if (error != nil) {
										 NSLog(@"[%@ %@]: FATAL: Failed to initialise SPSession with error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
										 abort();
									 }

									 [[SPSession sharedSession] setDelegate:self];
								 }];
}

-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	// When quitting, you should logout and wait for logout completion before terminating.
	if ([SPSession sharedSession].connectionState == SP_CONNECTION_STATE_LOGGED_OUT ||
		[SPSession sharedSession].connectionState == SP_CONNECTION_STATE_UNDEFINED)
		return NSTerminateNow;

	[[SPSession sharedSession] logout:^{
		[[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
	}];
	return NSTerminateLater;
}

#pragma mark -
#pragma mark SPSessionDelegate Methods

-(void)sessionDidLoginSuccessfully:(SPSession *)aSession {
	// Called after a successful login.
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error {
	// Called after a failed login.
    [NSApp presentError:error
         modalForWindow:self.window
               delegate:nil
     didPresentSelector:nil
            contextInfo:nil];
}

-(void)sessionDidLogOut:(SPSession *)aSession; {
	// Called after a logout has been completed.
}

-(void)session:(SPSession *)aSession didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName {

	// Called when login credentials are created. If you want to save user logins, uncomment the code below.

	/*
	 NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	 NSMutableDictionary *storedCredentials = [[defaults valueForKey:@"SpotifyUsers"] mutableCopy];

	 if (storedCredentials == nil)
	 storedCredentials = [NSMutableDictionary dictionary];

	 [storedCredentials setValue:credential forKey:userName];
	 [defaults setValue:storedCredentials forKey:@"SpotifyUsers"];
	 */
}

-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error; {
	if (SP_LIBSPOTIFY_DEBUG_LOGGING != 0)
		NSLog(@"CocoaLS NETWORK ERROR: %@", error);
}

-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage; {
	if (SP_LIBSPOTIFY_DEBUG_LOGGING != 0)
		NSLog(@"CocoaLS DEBUG: %@", aMessage);
}

-(void)sessionDidChangeMetadata:(SPSession *)aSession; {
	// Called when metadata has been updated somewhere in the
	// CocoaLibSpotify object model. You don't normally need to do
	// anything here. KVO on the metadata you're interested in instead.
}

-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage; {
	// Called when the Spotify service wants to relay a piece of information to the user.
	[[NSAlert alertWithMessageText:aMessage
					 defaultButton:@"OK"
				   alternateButton:@""
					   otherButton:@""
		 informativeTextWithFormat:@"This message was sent to you from the Spotify service."] runModal];
}


@end
