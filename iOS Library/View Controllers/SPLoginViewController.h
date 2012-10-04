//
//  SPLoginViewController.h
//  Simple Player
//
//  Created by Daniel Kennett on 10/3/11.
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

#import <UIKit/UIKit.h>
#import "CocoaLibSpotify.h"
#import "SPSignupViewController.h"

@class SPLoginViewController;

/**
 Provides a completion callback from SPLoginViewController. SPLoginViewController
 can cause multiple login and logout events during the login and signup process. This
 delegate informs you when the process is complete.
 */
@protocol SPLoginViewControllerDelegate <NSObject>

/** Called when the login/signup process has completed.
 
 @param controller The SPLoginViewController instance that generated the message.
 @param didLogin `YES` if the user successfully logged in, otherwise `NO`..
 */
-(void)loginViewController:(SPLoginViewController *)controller didCompleteSuccessfully:(BOOL)didLogin;

@end

/** This class provides a Spotify-designed login and signup flow for your application. iOS only.
 
 @warning *Important:* You must also include the provided `SPLoginResources.bundle` bundle 
 as a resource in your application to use this class.
 
 If you want to save the user's details for automatic login, use the appropriate `SPSession`
 delegate method to receive login credentials for storage (don't store the user's raw password),
 then login directly next time using the saved credentias instead of using this view controller.
 If login fails, display the appropriate error and you can then show this view controller for logging in manually again if needed.
 */
@interface SPLoginViewController : UINavigationController <SPSignupPageDelegate> {
	SPSession *session;
	BOOL waitingForFacebookPermissions;
	id <SPLoginViewControllerDelegate> __unsafe_unretained loginDelegate;
}

/** Returns an SPLoginViewController instance for the given session. 
 
 @param session The session to create the SPLoginViewController instance for.
 @return The created SPLoginViewController instance.
 */
+(SPLoginViewController *)loginControllerForSession:(SPSession *)session;

/** Returns whether the view controller allows the user to cancel the login process or not. Defaults to `YES`. */
@property (nonatomic, readwrite) BOOL allowsCancel;

/** Returns whether the view controller dismisses itself after the user successfully logs in. Defaults to `YES`. */
@property (nonatomic, readwrite) BOOL dismissesAfterLogin;

/** Returns the controller's loginDelegate object. */
@property (nonatomic, readwrite, unsafe_unretained) id <SPLoginViewControllerDelegate> loginDelegate;

@end

