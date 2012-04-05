//
//  SPPostTracksToInboxOperation.h
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 4/24/11.
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

/** This class provides functionality for sending tracks to another Spotify user. */

#import <Foundation/Foundation.h>
#import "CocoaLibSpotifyPlatformImports.h"

@class SPSession;
@protocol SPPostTracksToInboxOperationDelegate;

@interface SPPostTracksToInboxOperation : NSObject

///----------------------------
/// @name Creating and Initializing Track Post Operations
///----------------------------

/** Creates an SPPostTracksToInboxOperation for the given details.
 
 This convenience method is simply returns a new, autoreleased SPPostTracksToInboxOperation
 object. No caching is performed.
 
 @warning *Important:* Tracks will be posted to the given user as soon as a SPPostTracksToInboxOperation
 object is created. Be sure you want to post the tracks before creating the object!
 
 @param tracksToSend An array of SPTrack objects to send.
 @param user The username of the user to send the tracks to.
 @param aFriendlyGreeting The message to send with the tracks, if any.
 @param aSession The session to send the tracks with.
 @param completionDelegate The delegate to send success/failure messages to.
 @return Returns the created SPPostTracksToInboxOperation object. 
 */
+(SPPostTracksToInboxOperation *)sendTracks:(NSArray *)tracksToSend
									 toUser:(NSString *)user 
									message:(NSString *)aFriendlyGreeting
								  inSession:(SPSession *)aSession
								   delegate:(id <SPPostTracksToInboxOperationDelegate>)completionDelegate;

/** Initializes an SPPostTracksToInboxOperation for the given details.
 
 @warning *Important:* Tracks will be posted to the given user as soon as a SPPostTracksToInboxOperation
 object is created. Be sure you want to post the tracks before creating the object!
 
 @param tracksToSend An array of SPTrack objects to send.
 @param user The username of the user to send the tracks to.
 @param aFriendlyGreeting The message to send with the tracks, if any.
 @param aSession The session to send the tracks with.
 @param completionDelegate The delegate to send success/failure messages to.
 @return Returns the created SPPostTracksToInboxOperation object. 
 */
-(id)initBySendingTracks:(NSArray *)tracksToSend
				  toUser:(NSString *)user 
				 message:(NSString *)aFriendlyGreeting
			   inSession:(SPSession *)aSession
				delegate:(id <SPPostTracksToInboxOperationDelegate>)completionDelegate;

///----------------------------
/// @name Properties
///----------------------------

/** Returns the operation's delegate. */
@property (nonatomic, readonly, assign) __unsafe_unretained id <SPPostTracksToInboxOperationDelegate> delegate;

/** Returns the username of the user the tracks the operation is sending tracks to. */
@property (nonatomic, readonly, copy) NSString *destinationUser;

/** Returns the opaque structure used by the C LibSpotify API. 
 
 @warning *Important:* This should only be used if you plan to directly use the 
 C LibSpotify API. The behaviour of CocoaLibSpotify is undefined if you use the C
 API directly on items that have CocoaLibSpotify objects associated with them. 
 */
@property (nonatomic, readonly, assign) sp_inbox *inboxOperation;

/** Returns the message being sent. */
@property (nonatomic, readonly, copy) NSString *message;

/** Returns the session the tracks are being sent in. */
@property (nonatomic, readonly, strong) SPSession *session;

/** Returns the tracks being sent. */
@property (nonatomic, readonly, copy) NSArray *tracks;

@end

/** Delegate callbacks from SPPostTracksToInboxOperation on success or failure. */

@protocol SPPostTracksToInboxOperationDelegate <NSObject>
@optional

/** Called when the given post operation succeeded. 
 
 @param operation The operation that succeeded.
 */
-(void)postTracksToInboxOperationDidSucceed:(SPPostTracksToInboxOperation *)operation;

/** Called when the given post operation failed. 
 
 @param operation The operation that failed.
 @param error The error that caused the failure.
 */
-(void)postTracksToInboxOperation:(SPPostTracksToInboxOperation *)operation didFailWithError:(NSError *)error;

@end