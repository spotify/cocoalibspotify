//
//  SPCoreAudioController.m
//  Viva
//
//  Created by Daniel Kennett on 04/02/2012.
//  For license information, see LICENSE.markdown
//

#import "SPCoreAudioController.h"
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

@interface SPCoreAudioController ()

// Core Audio
-(BOOL)setupCoreAudioWithInputFormat:(AudioStreamBasicDescription)inputFormat error:(NSError **)err;
-(void)teardownCoreAudio;
-(void)startAudioQueue;
-(void)stopAudioQueue;
-(void)applyVolumeToMixerAudioUnit:(double)vol;
-(void)applyAudioStreamDescriptionToInputUnit:(AudioStreamBasicDescription)newInputDescription;

@property (readwrite, nonatomic) AudioStreamBasicDescription inputAudioDescription;

static OSStatus AudioUnitRenderDelegateCallback(void *inRefCon,
												AudioUnitRenderActionFlags *ioActionFlags,
												const AudioTimeStamp *inTimeStamp,
												UInt32 inBusNumber,
												UInt32 inNumberFrames,
												AudioBufferList *ioData);

@property (readwrite, strong, nonatomic) SPCircularBuffer *audioBuffer;

@end

static NSTimeInterval const kTargetBufferLength = 0.5;

@implementation SPCoreAudioController {
	
	AUGraph audioProcessingGraph;
	AudioUnit outputUnit;
	AudioUnit mixerUnit;
	AudioUnit inputConverterUnit;
	
	AUNode outputNode;
	AUNode inputConverterNode;
	AUNode mixerNode;
	
	UInt32 framesSinceLastTimeUpdate;
	
	NSMethodSignature *incrementTrackPositionMethodSignature;
	NSInvocation *incrementTrackPositionInvocation;
}

-(id)init {
	self = [super init];
	
	if (self) {
		self.volume = 1.0;
		self.audioOutputEnabled = NO; // Don't start audio playback until we're told.
		
		SEL incrementTrackPositionSelector = @selector(incrementTrackPositionWithFrameCount:);
		incrementTrackPositionMethodSignature = [SPCoreAudioController instanceMethodSignatureForSelector:incrementTrackPositionSelector];
		incrementTrackPositionInvocation = [NSInvocation invocationWithMethodSignature:incrementTrackPositionMethodSignature];
		[incrementTrackPositionInvocation setSelector:incrementTrackPositionSelector];
		[incrementTrackPositionInvocation setTarget:self];
		
		[self addObserver:self forKeyPath:@"volume" options:0 context:nil];
		[self addObserver:self forKeyPath:@"audioOutputEnabled" options:0 context:nil];
		
	}
	return self;
}

-(void)dealloc {
	
	[self removeObserver:self forKeyPath:@"volume"];
	[self removeObserver:self forKeyPath:@"audioOutputEnabled"];
	
	[self clearAudioBuffers];
	self.audioOutputEnabled = NO;
	[self teardownCoreAudio];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ([keyPath isEqualToString:@"volume"]) {
		[self applyVolumeToMixerAudioUnit:self.volume];
		
	} else if ([keyPath isEqualToString:@"audioOutputEnabled"]) {
		if (self.audioOutputEnabled)
			[self startAudioQueue];
		else
			[self stopAudioQueue];
	} else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@synthesize volume;
@synthesize audioOutputEnabled;
@synthesize audioBuffer;
@synthesize inputAudioDescription;
@synthesize delegate;

#pragma mark -
#pragma mark CocoaLS Audio Delivery

-(NSInteger)session:(id <SPSessionPlaybackProvider>)aSession shouldDeliverAudioFrames:(const void *)audioFrames ofCount:(NSInteger)frameCount streamDescription:(AudioStreamBasicDescription)audioDescription {
	
	if (frameCount == 0) {
		[self clearAudioBuffers];
		return 0; // Audio discontinuity!
	}
	
    if (audioProcessingGraph == NULL) {
        NSError *error = nil;
        if (![self setupCoreAudioWithInputFormat:audioDescription error:&error]) {
            NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
            return 0;
        }
    }
	
	AudioStreamBasicDescription currentAudioInputDescription = self.inputAudioDescription;
	
	if (audioDescription.mBitsPerChannel != currentAudioInputDescription.mBitsPerChannel ||
		audioDescription.mBytesPerFrame != currentAudioInputDescription.mBytesPerFrame ||
		audioDescription.mChannelsPerFrame != currentAudioInputDescription.mChannelsPerFrame ||
		audioDescription.mFormatFlags != currentAudioInputDescription.mFormatFlags ||
		audioDescription.mFormatID != currentAudioInputDescription.mFormatID ||
		audioDescription.mSampleRate != currentAudioInputDescription.mSampleRate) {
		// New format. Panic!! I mean, calmly tell Core Audio that a new audio format is incoming.
		[self clearAudioBuffers];
		[self applyAudioStreamDescriptionToInputUnit:audioDescription];
	}
	
	NSUInteger dataLength = frameCount * audioDescription.mBytesPerPacket;
	
	if ((self.audioBuffer.maximumLength - self.audioBuffer.length) < dataLength) {
		// Only allow whole deliveries in, since libSpotify wants us to consume whole frames, whereas
		// the buffer works in bytes, meaning we could consume a fraction of a frame.
		return 0;
	}
	
	[self.audioBuffer attemptAppendData:audioFrames ofLength:dataLength];
	return frameCount;	
}


#pragma mark -
#pragma mark Audio Unit Properties

-(void)applyVolumeToMixerAudioUnit:(double)vol {
    
    if (audioProcessingGraph == NULL || mixerUnit == NULL)
        return;
	
	OSErr status = AudioUnitSetParameter(mixerUnit,
										 kMultiChannelMixerParam_Volume,
										 kAudioUnitScope_Output, 
										 0,
										 vol * vol * vol,
										 0);
	
	if (status != noErr) {
		NSError *error;
        fillWithError(&error, @"Couldn't set input format", status);
		NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
    }
}

-(void)applyAudioStreamDescriptionToInputUnit:(AudioStreamBasicDescription)newInputDescription {
	
	if (audioProcessingGraph == NULL || inputConverterUnit == NULL)
		return;
	
	OSStatus status = AudioUnitSetProperty(inputConverterUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  0,
								  &newInputDescription,
								  sizeof(newInputDescription));
	if (status != noErr) {
		NSError *error;
        fillWithError(&error, @"Couldn't set input format", status);
		NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
    } else {
		self.inputAudioDescription = newInputDescription;
		[self clearAudioBuffers];
		self.audioBuffer = [[SPCircularBuffer alloc] initWithMaximumLength:(newInputDescription.mBytesPerFrame * newInputDescription.mSampleRate) * kTargetBufferLength];
	}
}

#pragma mark -
#pragma mark Queue Control

-(void)startAudioQueue {
    if (audioProcessingGraph == NULL)
        return;
    
    AUGraphStart(audioProcessingGraph);
	if (outputUnit != NULL)
		AudioOutputUnitStart(outputUnit);
}

-(void)stopAudioQueue {
    if (audioProcessingGraph == NULL)
        return;
    
	// Sometimes, because Core Audio is such a young, untested API, AUGraphStop… doesn't.
	// There's probably some dumb thing I'm doing wrong here.
	Boolean isRunning = NO;
	AUGraphIsRunning(audioProcessingGraph, &isRunning);
	
	for (NSUInteger i = 0; i < 10 && isRunning; i++) {
		AUGraphStop(audioProcessingGraph);
		AUGraphIsRunning(audioProcessingGraph, &isRunning);
	}
	
	if (isRunning)
		NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"Failed to stop audio graph!");
	
	// Forcefully stop the output audio unit too.
	if (outputUnit != NULL)
		AudioOutputUnitStop(outputUnit);
}

-(void)clearAudioBuffers {
	[self.audioBuffer clear];
}

#pragma mark -
#pragma mark Setup and Teardown

-(void)teardownCoreAudio {
    if (audioProcessingGraph == NULL)
        return;
    
    [self stopAudioQueue];
	
    AUGraphStop(audioProcessingGraph);
	
	[self disposeOfCustomNodesInGraph:audioProcessingGraph];
	
	AUGraphUninitialize(audioProcessingGraph);
	DisposeAUGraph(audioProcessingGraph);
	
#if TARGET_OS_IPHONE
	[[AVAudioSession sharedInstance] setActive:NO error:nil];
#endif
	
	audioProcessingGraph = NULL;
	outputUnit = NULL;
	mixerUnit = NULL;
	inputConverterUnit = NULL;
}

-(void)disposeOfCustomNodesInGraph:(AUGraph)graph {
	// Empty implementation — for subclasses to override.
}

-(BOOL)setupCoreAudioWithInputFormat:(AudioStreamBasicDescription)inputFormat error:(NSError **)err {
    
    if (audioProcessingGraph != NULL)
        [self teardownCoreAudio];
	
#if TARGET_OS_IPHONE
	NSError *error = nil;
	BOOL success = YES;
	success &= [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
	success &= [[AVAudioSession sharedInstance] setActive:YES error:&error];
	
	if (!success && err != NULL) {
		*err = error;
		return NO;
	}
#endif
	
    // A description of the output device we're looking for.
    AudioComponentDescription outputDescription;
	outputDescription.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
	outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
#else
    outputDescription.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputDescription.componentFlags = 0;
    outputDescription.componentFlagsMask = 0;
	
	// A description of the mixer unit
	AudioComponentDescription mixerDescription;
	mixerDescription.componentType = kAudioUnitType_Mixer;
	mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
	mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	mixerDescription.componentFlags = 0;
	mixerDescription.componentFlagsMask = 0;
	
	// A description for the libspotify -> standard PCM device
	AudioComponentDescription converterDescription;
	converterDescription.componentType = kAudioUnitType_FormatConverter;
	converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
	converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	converterDescription.componentFlags = 0;
	converterDescription.componentFlagsMask = 0;
    
	// Create an AUGraph
	OSErr status = NewAUGraph(&audioProcessingGraph);
	if (status != noErr) {
        fillWithError(err, @"Couldn't init graph", status);
        return NO;
    }
	
	// Open the graph. AudioUnits are open but not initialized (no resource allocation occurs here)
	AUGraphOpen(audioProcessingGraph);
	if (status != noErr) {
        fillWithError(err, @"Couldn't open graph", status);
        return NO;
    }
	
	// Add audio output...
	status = AUGraphAddNode(audioProcessingGraph, &outputDescription, &outputNode);
	if (status != noErr) {
        fillWithError(err, @"Couldn't add output node", status);
        return NO;
    }
	
	// Get output unit
	status = AUGraphNodeInfo(audioProcessingGraph, outputNode, NULL, &outputUnit);
	if (status != noErr) {
        fillWithError(err, @"Couldn't get output unit", status);
        return NO;
    }
	
	// Add mixer
	status = AUGraphAddNode(audioProcessingGraph, &mixerDescription, &mixerNode);
	if (status != noErr) {
        fillWithError(err, @"Couldn't add mixer node", status);
        return NO;
    }
	
	// Get mixer unit so we can change volume etc
	status = AUGraphNodeInfo(audioProcessingGraph, mixerNode, NULL, &mixerUnit);
	if (status != noErr) {
        fillWithError(err, @"Couldn't get mixer unit", status);
        return NO;
    }
	
	// Set mixer bus count
	UInt32 busCount = 1;
	status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
	if (status != noErr) {
        fillWithError(err, @"Couldn't set mixer bus count", status);
        return NO;
    }
	
	// Set mixer input volume
	status = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
	if (status != noErr) {
        fillWithError(err, @"Couldn't set mixer volume", status);
        return NO;
    }
	
	// Create PCM converter
	status = AUGraphAddNode(audioProcessingGraph, &converterDescription, &inputConverterNode);
	if (status != noErr) {
        fillWithError(err, @"Couldn't add converter node", status);
        return NO;
    }
	
	status = AUGraphNodeInfo(audioProcessingGraph, inputConverterNode, NULL, &inputConverterUnit);
	if (status != noErr) {
        fillWithError(err, @"Couldn't get input unit", status);
        return NO;
    }
	
	// Connect mixer to output
	status = AUGraphConnectNodeInput(audioProcessingGraph, mixerNode, 0, outputNode, 0);
	if (status != noErr) {
        fillWithError(err, @"Couldn't connect mixer to output", status);
        return NO;
    }
	
	if (![self connectOutputBus:0 ofNode:inputConverterNode toInputBus:0 ofNode:mixerNode inGraph:audioProcessingGraph error:err])
		return NO;
	
	// Set render callback
	AURenderCallbackStruct rcbs;
	rcbs.inputProc = AudioUnitRenderDelegateCallback;
	rcbs.inputProcRefCon = (__bridge void *)(self);
	
	status = AUGraphSetNodeInputCallback(audioProcessingGraph, inputConverterNode, 0, &rcbs);
	if (status != noErr) {
        fillWithError(err, @"Couldn't add render callback", status);
        return NO;
    }
	
	// Finally, set the kAudioUnitProperty_MaximumFramesPerSlice of each unit 
	// to 4096, to allow playback on iOS when the screen is locked.
	// Code based on http://developer.apple.com/library/ios/#qa/qa1606/_index.html
	
	UInt32 maxFramesPerSlice = 4096;
	status = AudioUnitSetProperty(inputConverterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice));
	status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice));
	status = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice));
	
	if (status != noErr) {
		fillWithError(err, @"Couldn't set max frames per slice", status);
        return NO;
	}
	
	// Init Queue
	status = AUGraphInitialize(audioProcessingGraph);
	if (status != noErr) {
		fillWithError(err, @"Couldn't initialize graph", status);
        return NO;
	}
	
	AUGraphUpdate(audioProcessingGraph, NULL);
	
	// Apply properties and let's get going!
    [self startAudioQueue];
	[self applyAudioStreamDescriptionToInputUnit:inputFormat];
    [self applyVolumeToMixerAudioUnit:self.volume];
	
    return YES;
}

-(BOOL)connectOutputBus:(UInt32)sourceOutputBusNumber ofNode:(AUNode)sourceNode toInputBus:(UInt32)destinationInputBusNumber ofNode:(AUNode)destinationNode inGraph:(AUGraph)graph error:(NSError **)error {
	
	// Connect converter to mixer
	OSStatus status = AUGraphConnectNodeInput(graph, sourceNode, sourceOutputBusNumber, destinationNode, destinationInputBusNumber);
	if (status != noErr) {
		fillWithError(error, @"Couldn't connect converter to mixer", status);
		return NO;
    }
	
	return YES;
}

static void fillWithError(NSError **mayBeAnError, NSString *localizedDescription, int code) {
    if (mayBeAnError == NULL)
        return;
    
    *mayBeAnError = [NSError errorWithDomain:@"com.CocoaLibSpotify.SPCoreAudioController"
                                        code:code
                                    userInfo:localizedDescription ? [NSDictionary dictionaryWithObject:localizedDescription
                                                                                                forKey:NSLocalizedDescriptionKey]
                                            : nil];
    
}

static OSStatus AudioUnitRenderDelegateCallback(void *inRefCon,
												AudioUnitRenderActionFlags *ioActionFlags,
												const AudioTimeStamp *inTimeStamp,
												UInt32 inBusNumber,
												UInt32 inNumberFrames,
												AudioBufferList *ioData) {
	
    SPCoreAudioController *self = (__bridge SPCoreAudioController *)inRefCon;
	
	AudioBuffer *buffer = &(ioData->mBuffers[0]);
	UInt32 bytesRequired = buffer->mDataByteSize;
	
	NSUInteger availableData = [self.audioBuffer length];
	if (availableData < bytesRequired) {
		buffer->mDataByteSize = 0;
		*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
		return noErr;
    }
    
    buffer->mDataByteSize = (UInt32)[self.audioBuffer readDataOfLength:bytesRequired intoAllocatedBuffer:&buffer->mData];
    
	self->framesSinceLastTimeUpdate += inNumberFrames;
	
	if (self->framesSinceLastTimeUpdate >= 8820) {
        // Update 5 times per second
		
		@autoreleasepool {
			
			[self->incrementTrackPositionInvocation setArgument:&self->framesSinceLastTimeUpdate atIndex:2];
			[self->incrementTrackPositionInvocation performSelectorOnMainThread:@selector(invoke)
																	 withObject:nil
																  waitUntilDone:NO];
			self->framesSinceLastTimeUpdate = 0;
			
		}
	}
    
    return noErr;
}

-(void)incrementTrackPositionWithFrameCount:(UInt32)framesToAppend {
	[self.delegate coreAudioController:self didOutputAudioOfDuration:framesToAppend/self.inputAudioDescription.mSampleRate];
}

@end
