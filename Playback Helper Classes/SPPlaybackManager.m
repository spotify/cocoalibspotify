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

@interface SPPlaybackManager ()

@property (nonatomic, readwrite, retain) SPCircularBuffer *audioBuffer;
@property (nonatomic, readwrite, retain) SPTrack *currentTrack;
@property (nonatomic, readwrite, retain) SPSession *playbackSession;

@property (readwrite) NSTimeInterval trackPosition;

-(void)informDelegateOfAudioPlaybackStarting;

// Core Audio
-(BOOL)setupCoreAudioWithAudioFormat:(const sp_audioformat *)audioFormat error:(NSError **)err;
-(void)teardownCoreAudio;
-(void)startAudioUnit;
-(void)stopAudioUnit;
-(void)applyVolumeToAudioUnit:(double)vol;

static OSStatus SPPlaybackManagerAudioUnitRenderDelegateCallback(void *inRefCon,
                                                                 AudioUnitRenderActionFlags *ioActionFlags,
                                                                 const AudioTimeStamp *inTimeStamp,
                                                                 UInt32 inBusNumber,
                                                                 UInt32 inNumberFrames,
                                                                 AudioBufferList *ioData);

@end

static NSString * const kSPPlaybackManagerKVOContext = @"kSPPlaybackManagerKVOContext"; 
static NSUInteger const kMaximumBytesInBuffer = 44100 * 2 * 2 * 0.5; // 0.5 Second @ 44.1kHz, 16bit per channel, stereo
static NSUInteger const kUpdateTrackPositionHz = 5;

@implementation SPPlaybackManager

-(id)initWithPlaybackSession:(SPSession *)aSession {
    
    if ((self = [super init])) {
        
        self.playbackSession = aSession;
		self.playbackSession.playbackDelegate = (id)self;
		self.volume = 1.0;
		self.audioBuffer = [[[SPCircularBuffer alloc] initWithMaximumLength:kMaximumBytesInBuffer] autorelease];
		
		[self addObserver:self
			   forKeyPath:@"playbackSession.playing"
				  options:0
				  context:kSPPlaybackManagerKVOContext];
        
        // We pre-allocate the NSInvocation for setting the current playback time for performance reasons.
        // See SPPlaybackManagerAudioUnitRenderDelegateCallback() for more.
        SEL incrementTrackPositionSelector = @selector(incrementTrackPositionWithFrameCount:);
		incrementTrackPositionMethodSignature = [[SPPlaybackManager instanceMethodSignatureForSelector:incrementTrackPositionSelector] retain];
		incrementTrackPositionInvocation = [[NSInvocation invocationWithMethodSignature:incrementTrackPositionMethodSignature] retain];
		[incrementTrackPositionInvocation setSelector:incrementTrackPositionSelector];
		[incrementTrackPositionInvocation setTarget:self];
    }
    return self;
}

-(void)dealloc {
	
	[self removeObserver:self forKeyPath:@"playbackSession.playing"];
	
	self.playbackSession.playbackDelegate = nil;
	self.playbackSession = nil;
	self.currentTrack = nil;
	
	[self teardownCoreAudio];
	[self.audioBuffer clear];
	self.audioBuffer = nil;
    
	incrementTrackPositionInvocation.target = nil;
    [incrementTrackPositionInvocation release];
	incrementTrackPositionInvocation = nil;
	[incrementTrackPositionMethodSignature release];
	incrementTrackPositionMethodSignature = nil;
	
    [super dealloc];
}

@synthesize audioBuffer;
@synthesize playbackSession;
@synthesize trackPosition;
@synthesize volume;
@synthesize delegate;

@synthesize currentTrack;

-(BOOL)playTrack:(SPTrack *)trackToPlay error:(NSError **)error {
	
	self.playbackSession.playing = NO;
	[self.playbackSession unloadPlayback];
	[self teardownCoreAudio];
	[self.audioBuffer clear];
	
	if (trackToPlay.availability != SP_TRACK_AVAILABILITY_AVAILABLE) {
		if (error != NULL) *error = [NSError spotifyErrorWithCode:SP_ERROR_TRACK_NOT_PLAYABLE];
		self.currentTrack = nil;
		return NO;
	}
		
	self.currentTrack = trackToPlay;
	self.trackPosition = 0.0;
	BOOL result = [self.playbackSession playTrack:self.currentTrack error:error];
	if (result)
		self.playbackSession.playing = YES;
	else
		self.currentTrack = nil;
	
	return result;
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
        if (self.playbackSession.isPlaying) {
			[self startAudioUnit];
		} else {
            // Explicitly stop the audio unit, otherwise it'll continue playing audio from the buffers it has.
			[self stopAudioUnit];
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
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
	self.currentTrack = nil;	
}

#pragma mark -
#pragma mark Core Audio Setup

-(void)applyVolumeToAudioUnit:(double)vol {
    
    if (outputAudioUnit == NULL)
        return;
    
    // Set the volume parameter of our audio unit.
    // On the Mac, a logarithmic curve sounds best.
    AudioUnitSetParameter(outputAudioUnit,
                          kHALOutputParam_Volume,
                          kAudioUnitScope_Output,
                          0,
                          (vol * vol * vol),
                          0);
}

-(void)startAudioUnit {
    if (outputAudioUnit == NULL)
        return;
    
    // Start the audio unit. Until this is called, no sound will happen.
    AudioOutputUnitStart(outputAudioUnit);
}

-(void)stopAudioUnit {
    if (outputAudioUnit == NULL)
        return;
    
    // Stop the audio unit immdediately, ceasing sound output 
    // even if Core Audio has audio left in its buffer.
    AudioOutputUnitStop(outputAudioUnit);
}

-(void)teardownCoreAudio {
    if (outputAudioUnit == NULL)
        return;
    
    // Tear down the audio init properly.
    [self stopAudioUnit];
    AudioUnitUninitialize(outputAudioUnit);
	
#if TARGET_OS_IPHONE
	AudioComponentInstanceDispose(outputAudioUnit);
	[[AVAudioSession sharedInstance] setActive:NO error:nil];
#else 
    CloseComponent(outputAudioUnit);
#endif
    outputAudioUnit = NULL;
	currentCoreAudioSampleRate = 0;
}

static inline void fillWithError(NSError **mayBeAnError, NSString *localizedDescription, int code) {
    
    if (mayBeAnError == NULL)
        return;
    
    *mayBeAnError = [NSError errorWithDomain:@"com.spplaybackmanager.coreaudio"
                                        code:code
                                    userInfo:localizedDescription ? [NSDictionary dictionaryWithObject:localizedDescription
                                                                                                forKey:NSLocalizedDescriptionKey]
                                            : nil];
    
}

-(BOOL)setupCoreAudioWithAudioFormat:(const sp_audioformat *)audioFormat error:(NSError **)err {
    
    if (outputAudioUnit != NULL)
        [self teardownCoreAudio];
	
	// Set up some platform-specific things
#if TARGET_OS_IPHONE
	
	NSError *error = nil;
	BOOL success = YES;
	success &= [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
	success &= [[AVAudioSession sharedInstance] setActive:YES error:&error];
	
	if (!success && err != NULL) {
		*err = error;
		return NO;
	}
	
	AudioComponentDescription desc;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
#else
	ComponentDescription desc;
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
	
	// Find the system default audio output by creating a component description and
    // searching for attached output components that match. If no components are connected
    // (like, say, a G4 Cube with no audio devices) this will fail.
    desc.componentType = kAudioUnitType_Output;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // Find a component that meets the description's specifications
#if TARGET_OS_IPHONE
	AudioComponent comp = AudioComponentFindNext(NULL, &desc);
#else
	Component comp = FindNextComponent(NULL, &desc);
#endif
	
    if (comp == NULL) {
        fillWithError(err, @"Could not find a component that matches our specifications", -1);
        return NO;
    }
	
    // Attempt to gain access to the audio component.
    OSErr status = noErr;
	
#if TARGET_OS_IPHONE
	status = AudioComponentInstanceNew(comp, &outputAudioUnit);
#else
	status = OpenAComponent(comp, &outputAudioUnit);
#endif
	
    if (status != noErr) {
        fillWithError(err, @"Couldn't find a device that matched our criteria", status);
        return NO;
    }
    
    // Tell Core Audio about libspotify's audio format. By default, Core Audio wants
    // non-interleaved, floating-point PCM which is pretty much opposite to what 
    // libspotify gives us. Specifying the format this way prevents us having to manually
    // convert the data later.
    AudioStreamBasicDescription outputFormat;
    outputFormat.mSampleRate = (float)audioFormat->sample_rate;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    outputFormat.mBytesPerPacket = audioFormat->channels * sizeof(SInt16);
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mBytesPerFrame = outputFormat.mBytesPerPacket;
    outputFormat.mChannelsPerFrame = audioFormat->channels;
    outputFormat.mBitsPerChannel = 16;
    outputFormat.mReserved = 0;
    
    status = AudioUnitSetProperty(outputAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status != noErr) {
        fillWithError(err, @"Couldn't set output format", status);
        return NO;
    }
    
    // Set the render callback, which will be called by Core Audio when it requires data
    // for its buffers.
    AURenderCallbackStruct callback;
    callback.inputProc = SPPlaybackManagerAudioUnitRenderDelegateCallback;
    callback.inputProcRefCon = self;
    
    status = AudioUnitSetProperty(outputAudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  0,
                                  &callback,
                                  sizeof(callback));
    if (status != noErr) {
        fillWithError(err, @"Couldn't set render callback", status);
        return NO;
    }
    
    // Initialize the audio unit with the applied settings.
    status = AudioUnitInitialize(outputAudioUnit);
    if (status != noErr) {
        fillWithError(err, @"Couldn't initialize audio unit", status);
        return NO;
    }
    
    // Start audio output (since we create the audio unit on-demand) and set the volume.
    currentCoreAudioSampleRate = audioFormat->sample_rate;
	[self startAudioUnit];
    [self applyVolumeToAudioUnit:self.volume];
    
    return YES;
}

#pragma mark -
#pragma mark Receiving Audio From CocoaLibSpotify

-(NSInteger)session:(SPSession *)aSession shouldDeliverAudioFrames:(const void *)audioFrames ofCount:(NSInteger)frameCount format:(const sp_audioformat *)audioFormat {
	
    // This is called by CocoaLibSpotify when there's audio data to be played. Since Core Audio uses callbacks as well to 
    // fetch data, we store the data in an intermediate buffer. This method is called on an aritrary thread, so everything
	// must be thread-safe. In addition, this method must not block - if your buffers are full, return 0 and the delivery will
	// be tried again later.
	
	[self retain]; // Try to avoid the object being deallocated while this is going on.
	
	if (frameCount == 0) {
		// If this happens (frameCount of 0), the user has seeked the track somewhere (or similar). 
		// Clear audio buffers and wait for more data.
		[self.audioBuffer clear];
		return 0;
	}
	
	if (audioFormat->sample_rate != currentCoreAudioSampleRate)
		// Spotify contains audio in various sample rates. If we encounter one different to the current
		// sample rate, we need to tear down our Core Audio setup and set it up again.
		[self teardownCoreAudio];
    
    if (outputAudioUnit == NULL) {
        // Setup Core Audio if it hasn't been set up yet.
        NSError *error = nil;
        if (![self setupCoreAudioWithAudioFormat:audioFormat error:&error]) {
            NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
            return 0;
        }
    }
	
	if (self.audioBuffer.length == 0)
		[self informDelegateOfAudioPlaybackStarting];
	
	NSUInteger frameByteSize = sizeof(SInt16) * audioFormat->channels;
	NSUInteger dataLength = frameCount * frameByteSize;
	
	if ((self.audioBuffer.maximumLength - self.audioBuffer.length) < dataLength) {
		// Only allow whole deliveries in, since libSpotify wants us to consume whole frames, whereas
		// the buffer works in bytes, meaning we could consume a fraction of a frame.
		return 0;
	}
	
	[self.audioBuffer attemptAppendData:audioFrames ofLength:dataLength];
	
	[self release];
	return frameCount;
}

-(void)informDelegateOfAudioPlaybackStarting {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:NO];
		return;
	}
	[self.delegate playbackManagerWillStartPlayingAudio:self];
}

#pragma mark -
#pragma mark Core Audio Render Callback

static UInt32 framesSinceLastTimeUpdate = 0;

static OSStatus SPPlaybackManagerAudioUnitRenderDelegateCallback(void *inRefCon,
                                                                 AudioUnitRenderActionFlags *ioActionFlags,
                                                                 const AudioTimeStamp *inTimeStamp,
                                                                 UInt32 inBusNumber,
                                                                 UInt32 inNumberFrames,
                                                                 AudioBufferList *ioData) {
    
    // This callback is called by Core Audio when it needs more audio data to fill its buffers.
    // This callback is both super time-sensitive and called on some arbitrary thread, so we
    // have to be extra careful with performance and locking.
    SPPlaybackManager *self = inRefCon;
	[self retain]; // Try to avoid the object being deallocated while this is going on.
	
	AudioBuffer *buffer = &(ioData->mBuffers[0]);
	UInt32 bytesRequired = buffer->mDataByteSize;
    framesSinceLastTimeUpdate += inNumberFrames;
	int sampleRate = self->currentCoreAudioSampleRate;
    
    // If we don't have enough data, tell Core Audio about it.
	NSUInteger availableData = [self->audioBuffer length];
	if (availableData < bytesRequired) {
		buffer->mDataByteSize = 0;
		*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
		[self release];
		return noErr;
    }
    
    // Since we told Core Audio about our audio format in -setupCoreAudioWithAudioFormat:error:,
    // we can simply copy data out of our buffer straight into the one given to us in the callback.
    // SPCircularBuffer deals with thread safety internally so we don't need to worry about it here.
    buffer->mDataByteSize = (UInt32)[self->audioBuffer readDataOfLength:bytesRequired intoAllocatedBuffer:&buffer->mData];
    
	if (sampleRate > 0 && framesSinceLastTimeUpdate >= sampleRate/kUpdateTrackPositionHz) {
        // Only update 5 times per second.
        // Since this render callback from Core Audio is so time-sensitive, we avoid allocating objects
        // and having to use an autorelease pool by pre-allocating the NSInvocation, setting its argument here
        // and setting it off on the main thread without waiting here. The -trackPosition property is atomic, so the
        // worst race condition that can happen is the property gets set out of order. Since we update at 5Hz, the 
        // chances of this happening are slim.
		[self->incrementTrackPositionInvocation setArgument:&framesSinceLastTimeUpdate atIndex:2];
		[self->incrementTrackPositionInvocation performSelectorOnMainThread:@selector(invoke)
                                                                 withObject:nil
                                                              waitUntilDone:NO];
		framesSinceLastTimeUpdate = 0;
	}
    
	[self release];
    return noErr;
}

-(void)incrementTrackPositionWithFrameCount:(UInt32)framesToAppend {
	if (currentCoreAudioSampleRate > 0)
		self.trackPosition = self.trackPosition + (double)framesToAppend/currentCoreAudioSampleRate;
}

@end
