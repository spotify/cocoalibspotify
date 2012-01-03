//
//  SPPlaybackManager.h
//  Guess The Intro
//
//  Created by Daniel Kennett on 06/05/2011.
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

#import <Foundation/Foundation.h>
#import "SPCircularBuffer.h"
#import <AudioUnit/AudioUnit.h>

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "CocoaLibSpotify.h"
#else
#import <CoreAudio/CoreAudio.h>
#import <CocoaLibSpotify/CocoaLibSpotify.h>
#endif

@class SPPlaybackManager;

@protocol SPPlaybackManagerDelegate <NSObject>

/** Called when audio starts playing. */
-(void)playbackManagerWillStartPlayingAudio:(SPPlaybackManager *)aPlaybackManager;

@end

@interface SPPlaybackManager : NSObject <SPSessionPlaybackDelegate> {
@private
	
	SPCircularBuffer *audioBuffer;
	AudioUnit outputAudioUnit;
    NSTimeInterval currentTrackPosition;
	SPSession *playbackSession;
	double volume;
	int currentCoreAudioSampleRate;
	SPTrack *currentTrack;
	NSTimeInterval trackPosition;
	id <SPPlaybackManagerDelegate> delegate;
    NSMethodSignature *incrementTrackPositionMethodSignature;
	NSInvocation *incrementTrackPositionInvocation;
}

/** Initialize a new SPPlaybackManager object. 
 
 @param aSession The session that should stream and decode audio data.
 @return Returns the created playback manager.
*/ 
-(id)initWithPlaybackSession:(SPSession *)aSession;

/** Returns the currently playing track, or `nil` if nothing is playing. */
@property (nonatomic, readonly, retain) SPTrack *currentTrack;

/** Returns the manager's delegate. */
@property (nonatomic, readwrite, assign) id <SPPlaybackManagerDelegate> delegate;

/** Returns the session that is performing decoding and playback. */
@property (nonatomic, readonly, retain) SPSession *playbackSession;

///----------------------------
/// @name Controlling Playback
///----------------------------

/** Returns `YES` if the track is currently playing, `NO` if not.
 
 If currentTrack is not `nil`, playback is paused.
 */
@property (readwrite) BOOL isPlaying;

/** Plays the given track.
 
 @param trackToPlay The track that should be played.
 @param error An `NSError` pointer reference that, if not `NULL`, will be filled with an error describing any failure. 
 @return Returns `YES` is playback started successfully, `NO` if not.
 */
-(BOOL)playTrack:(SPTrack *)trackToPlay error:(NSError **)error;

/** Seek the current playback position to the given time. 
 
 @param offset The time at which to seek to. Must be between 0.0 and the duration of the playing track.
 */
-(void)seekToTrackPosition:(NSTimeInterval)newPosition;

/** Returns the playback position of the current track, in the range 0.0 to the current track's duration. */
@property (readonly) NSTimeInterval trackPosition;

/** Returns the current playback volume, in the range 0.0 to 1.0. */
@property (readwrite) double volume;

@end
