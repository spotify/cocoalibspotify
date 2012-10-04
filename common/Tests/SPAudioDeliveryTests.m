//
//  SPAudioDeliveryTests.m
//  CocoaLibSpotify Mac Framework
//
//  Created by Daniel Kennett on 10/05/2012.
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

#import "SPAudioDeliveryTests.h"
#import "SPAsyncLoading.h"
#import "SPTrack.h"
#import "TestConstants.h"

@implementation SPAudioDeliveryTests {
	BOOL gotAudioDelivery;
}

-(void)testAudioDelivery {
	
	gotAudioDelivery = NO;
	
	[SPTrack trackForTrackURL:[NSURL URLWithString:kTrackLoadingTestURI]
					inSession:[SPSession sharedSession]
					 callback:^(SPTrack *track) {
						 
						 SPTestAssert(track != nil, @"Track is nil for %@", track);
						 
						 [SPAsyncLoading waitUntilLoaded:track timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
							 SPTestAssert(notLoadedItems.count == 0, @"Track loading timed out for %@", track);
							 
							 SPSession *session = [SPSession sharedSession];
							 session.audioDeliveryDelegate = self;
							 session.playbackDelegate = self;
							 
							 [session playTrack:track callback:^(NSError *error) {
								 SPTestAssert(error == nil, @"Track playback encountered error: %@", error);
								 [self performSelector:@selector(timeOutAudioDeliveryTest) withObject:nil afterDelay:kSPAsyncLoadingDefaultTimeout];
							 }];
						 }];
					 }];
}

-(void)timeOutAudioDeliveryTest {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeOutAudioDeliveryTest) object:nil];
	if (!gotAudioDelivery)
		dispatch_async(dispatch_get_main_queue(), ^{
			[self failTest:@selector(testAudioDelivery) format:@"Timeout waiting for audio delivery."];
		});
}

-(void)sessionDidLosePlayToken:(id <SPSessionPlaybackProvider>)aSession {}
-(void)sessionDidEndPlayback:(id <SPSessionPlaybackProvider>)aSession {}

-(void)session:(id <SPSessionPlaybackProvider>)aSession didEncounterStreamingError:(NSError *)error {
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeOutAudioDeliveryTest) object:nil];
	if (!gotAudioDelivery)
		dispatch_async(dispatch_get_main_queue(), ^{
			[self failTest:@selector(testAudioDelivery) format:@"Streaming error waiting for audio delivery: %@", error];
		});
}

-(NSInteger)session:(id <SPSessionPlaybackProvider>)aSession shouldDeliverAudioFrames:(const void *)audioFrames ofCount:(NSInteger)frameCount streamDescription:(AudioStreamBasicDescription)audioDescription {
	
	if (frameCount == 0) return 0;
	
	gotAudioDelivery = YES;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeOutAudioDeliveryTest) object:nil];
	
	aSession.playing = NO;
	[aSession unloadPlayback];
	[(SPSession *)aSession setAudioDeliveryDelegate:nil];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self passTest:@selector(testAudioDelivery)];
	});
	return 0;
}

@end
