//
//  SPPlaybackManager.m
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

#import "SPPlaybackManager.h"
#import "SPCoreAudioController.h"
#import "SPTrack.h"
#import "SPSession.h"
#import "SPErrorExtensions.h"

@interface SPPlaybackManager ()

@property (nonatomic, readwrite, strong) SPCoreAudioController *audioController;
@property (nonatomic, readwrite, strong) SPTrack *currentTrack;
@property (nonatomic, readwrite, strong) SPSession *playbackSession;

@property (readwrite) NSTimeInterval trackPosition;

-(void)informDelegateOfAudioPlaybackStarting;

@end

static void * const kSPPlaybackManagerKVOContext = @"kSPPlaybackManagerKVOContext"; 

@implementation SPPlaybackManager {
	NSMethodSignature *incrementTrackPositionMethodSignature;
	NSInvocation *incrementTrackPositionInvocation;
}

-(id)initWithPlaybackSession:(SPSession *)aSession {
    
    if ((self = [super init])) {
        
        self.playbackSession = aSession;
		self.playbackSession.playbackDelegate = (id)self;
		self.audioController = [[SPCoreAudioController alloc] init];
		self.audioController.delegate = self;
		self.playbackSession.audioDeliveryDelegate = self.audioController;
		
		[self addObserver:self
			   forKeyPath:@"playbackSession.playing"
				  options:0
				  context:kSPPlaybackManagerKVOContext];
	}
    return self;
}

-(id)initWithAudioController:(SPCoreAudioController *)aController playbackSession:(SPSession *)aSession {
	
	self = [self initWithPlaybackSession:aSession];
	
	if (self) {
		self.audioController = aController;
		self.audioController.delegate = self;
		self.playbackSession.audioDeliveryDelegate = self.audioController;
	}
	
	return self;
}

-(void)dealloc {
	
	[self removeObserver:self forKeyPath:@"playbackSession.playing"];
	
	self.playbackSession.playbackDelegate = nil;
	self.playbackSession = nil;
	self.currentTrack = nil;
	
	self.audioController.delegate = nil;
	self.audioController = nil;
}

@synthesize audioController;
@synthesize playbackSession;
@synthesize trackPosition;
@synthesize delegate;

+(NSSet *)keyPathsForValuesAffectingVolume {
	return [NSSet setWithObject:@"audioController.volume"];
}

-(double)volume {
	return self.audioController.volume;
}

-(void)setVolume:(double)volume {
	self.audioController.volume = volume;
}

@synthesize currentTrack;

-(void)playTrack:(SPTrack *)aTrack callback:(SPErrorableOperationCallback)block {
	
	self.playbackSession.playing = NO;
	[self.playbackSession unloadPlayback];
	[self.audioController clearAudioBuffers];
	
	if (aTrack.availability != SP_TRACK_AVAILABILITY_AVAILABLE) {
		if (block) block([NSError spotifyErrorWithCode:SP_ERROR_TRACK_NOT_PLAYABLE]);
        self.currentTrack = nil;
		self.trackPosition = 0.0;
		return;
	}
		
	self.currentTrack = aTrack;
	self.trackPosition = 0.0;
	
	[self.playbackSession playTrack:self.currentTrack callback:^(NSError *error) {
		
		if (!error)
			self.playbackSession.playing = YES;
		else
			self.currentTrack = nil;
		
		if (block) {
			block(error);
		}
	}];
}

-(void)seekToTrackPosition:(NSTimeInterval)newPosition {
	if (newPosition <= self.currentTrack.duration) {
		[self.playbackSession seekPlaybackToOffset:newPosition];
		self.trackPosition = newPosition;
	}	
}

+(NSSet *)keyPathsForValuesAffectingIsPlaying {
	return [NSSet setWithObject:@"playbackSession.playing"];
}

-(BOOL)isPlaying {
	return self.playbackSession.isPlaying;
}

-(void)setIsPlaying:(BOOL)isPlaying {
	self.playbackSession.playing = isPlaying;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
	if ([keyPath isEqualToString:@"playbackSession.playing"] && context == kSPPlaybackManagerKVOContext) {
        self.audioController.audioOutputEnabled = self.playbackSession.isPlaying;
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -
#pragma mark Audio Controller Delegate

-(void)coreAudioController:(SPCoreAudioController *)controller didOutputAudioOfDuration:(NSTimeInterval)audioDuration {
	
	if (self.trackPosition == 0.0)
		dispatch_async(dispatch_get_main_queue(), ^{ [self.delegate playbackManagerWillStartPlayingAudio:self]; });
	
	self.trackPosition += audioDuration;
}

#pragma mark -
#pragma mark Playback Callbacks

-(void)sessionDidLosePlayToken:(SPSession *)aSession {

	// This delegate is called when playback stops because the Spotify account is being used for playback elsewhere.
	// In practice, playback is only paused and you can call [SPSession -setIsPlaying:YES] to start playback again and 
	// pause the other client.

}

-(void)sessionDidEndPlayback:(SPSession *)aSession {
	
	// This delegate is called when playback stops naturally, at the end of a track.
	
	// Not routing this through to the main thread causes odd locks and crashes.
	[self performSelectorOnMainThread:@selector(sessionDidEndPlaybackOnMainThread:)
						   withObject:aSession
						waitUntilDone:NO];
}

-(void)sessionDidEndPlaybackOnMainThread:(SPSession *)aSession {
    if ([self.delegate respondsToSelector:@selector(playbackManagerIsFinishingPlayback:)])
        [self.delegate playbackManagerIsFinishingPlayback:self];
    self.currentTrack = nil;
}


-(void)informDelegateOfAudioPlaybackStarting {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:NO];
		return;
	}
	[self.delegate playbackManagerWillStartPlayingAudio:self];
}

@end
