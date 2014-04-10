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

#define SP_CA_CHECK(err, msg, status) \
if (status != noErr) { \
fillWithError(err, msg, status); \
return NO; \
}

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

#if !TARGET_OS_IPHONE

-(NSArray *)queryOutputDevices:(NSError **)error;
@property (readwrite, nonatomic, copy) NSArray *availableOutputDevices;

static OSStatus AOPropertyListenerProc(AudioObjectID inObjectID,
									   UInt32 inNumberAddresses,
									   const AudioObjectPropertyAddress inAddresses[],
									   void * inClientData);
#endif

@property (readwrite, strong, nonatomic) SPCircularBuffer *audioBuffer;

@end

static NSTimeInterval const kTargetBufferLength = 0.5;

@implementation SPCoreAudioController {

	AUGraph audioProcessingGraph;
	AudioUnit outputUnit, mixerUnit, inputConverterUnit;
	AUNode inputConverterNode, mixerNode, outputNode;

	UInt32 framesSinceLastTimeUpdate;
}

-(id)init {
	self = [super init];

	if (self) {
		self.volume = 1.0;
		self.audioOutputEnabled = NO; // Don't start audio playback until we're told.

		[self addObserver:self forKeyPath:@"volume" options:0 context:nil];
		[self addObserver:self forKeyPath:@"audioOutputEnabled" options:0 context:nil];

#if !TARGET_OS_IPHONE
		self.availableOutputDevices = [self queryOutputDevices:nil];
		[self addObserver:self forKeyPath:@"currentOutputDevice" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

		// Add observer for audio device changes
		AudioObjectPropertyAddress address;
		address.mSelector = kAudioHardwarePropertyDevices;
		address.mScope = kAudioObjectPropertyScopeGlobal;
		address.mElement = kAudioObjectPropertyElementMaster;
		AudioObjectAddPropertyListener(kAudioObjectSystemObject, &address, AOPropertyListenerProc, (__bridge void *)self);
#endif
	}
	return self;
}

-(void)dealloc {

#if !TARGET_OS_IPHONE
	// Remove observer for audio device changes
	AudioObjectPropertyAddress address;
	address.mSelector = kAudioHardwarePropertyDevices;
	address.mScope = kAudioObjectPropertyScopeGlobal;
	address.mElement = kAudioObjectPropertyElementMaster;
	AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &address, AOPropertyListenerProc, (__bridge void *)self);

	[self removeObserver:self forKeyPath:@"currentOutputDevice"];
#endif

	[self removeObserver:self forKeyPath:@"volume"];
	[self removeObserver:self forKeyPath:@"audioOutputEnabled"];

	[self clearAudioBuffers];
	self.audioOutputEnabled = NO;
	[self teardownCoreAudio];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ([keyPath isEqualToString:@"volume"]) {
		[self applyVolumeToMixerAudioUnit:self.volume];

#if !TARGET_OS_IPHONE
	} else if ([keyPath isEqualToString:@"currentOutputDevice"]) {

		if (outputUnit == NULL)
			return;

		id oldSelection = [change valueForKey:NSKeyValueChangeOldKey];
		id newSelection = [change valueForKey:NSKeyValueChangeNewKey];

		if ((oldSelection == [NSNull null] && newSelection != [NSNull null]) ||
			(oldSelection != [NSNull null] && newSelection == [NSNull null])) {
			// If the device is shifting to/from NULL, we need to change the output unit
			[self stopAudioQueue];
			NSError *error = nil;
			if (![self setupAudioOutputFromBus:0 ofNode:mixerNode inGraph:audioProcessingGraph error:&error])
				NSLog(@"Couldn't change output audio unit: %@", error);
			[self startAudioQueue];
		} else if (self.currentOutputDevice != nil) {
			NSError *error = nil;
			if (![self applyOutputDeviceWithUIDToAudioOutput:self.currentOutputDevice.UID error:&error])
				NSLog(@"Couldn't change output device: %@", error);
		}
#endif

	} else if ([keyPath isEqualToString:@"audioOutputEnabled"]) {
		if (self.audioOutputEnabled)
			[self startAudioQueue];
		else
			[self stopAudioQueue];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -
#pragma mark CocoaLS Audio Delivery

-(NSInteger)session:(id <SPSessionPlaybackProvider>)aSession shouldDeliverAudioFrames:(const void *)audioFrames ofCount:(NSInteger)frameCount streamDescription:(AudioStreamBasicDescription)audioDescription {

	if (frameCount == 0) {
		[self clearAudioBuffers];
		return 0; // Audio discontinuity!
	}

	NSError *error = nil;
	if (audioProcessingGraph == NULL && ![self setupCoreAudioWithInputFormat:audioDescription error:&error]) {
		NSLog(@"ERROR: Core audio setup failed: %@", error);
		return 0;
	}

	AudioStreamBasicDescription currentAudioInputDescription = self.inputAudioDescription;

	if (memcmp(&currentAudioInputDescription, &audioDescription, sizeof(AudioStreamBasicDescription)) != 0) {
		// New format. Panic!! I mean, calmly tell Core Audio that a new audio format is incoming.
		[self clearAudioBuffers];
		[self applyAudioStreamDescriptionToInputUnit:audioDescription];
	}

	NSUInteger bytesToAdd = frameCount * audioDescription.mBytesPerPacket;
	NSUInteger bytesAdded = [self.audioBuffer attemptAppendData:audioFrames
													   ofLength:bytesToAdd
													  chunkSize:audioDescription.mBytesPerPacket];

	NSUInteger framesAdded = bytesAdded / audioDescription.mBytesPerPacket;
	return framesAdded;
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

	Boolean isRunning = NO;
	AUGraphIsRunning(audioProcessingGraph, &isRunning);
	if (isRunning)
		return;

	AUGraphStart(audioProcessingGraph);
}

-(void)stopAudioQueue {
	if (audioProcessingGraph == NULL)
		return;

	Boolean isRunning = NO;
	AUGraphIsRunning(audioProcessingGraph, &isRunning);

	if (!isRunning)
		return;

	AUGraphStop(audioProcessingGraph);
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
	success &= [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
	success &= [[AVAudioSession sharedInstance] setActive:YES error:&error];

	if (!success && err != NULL) {
		*err = error;
		return NO;
	}
#endif

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

	// Create and open an AUGraph
	SP_CA_CHECK(err, @"Couldn't init graph", NewAUGraph(&audioProcessingGraph));
	SP_CA_CHECK(err, @"Couldn't open graph", AUGraphOpen(audioProcessingGraph));

	// Add mixer, get unit and set it up
	SP_CA_CHECK(err, @"Couldn't add mixer node", AUGraphAddNode(audioProcessingGraph, &mixerDescription, &mixerNode));
	SP_CA_CHECK(err, @"Couldn't get mixer unit", AUGraphNodeInfo(audioProcessingGraph, mixerNode, NULL, &mixerUnit));

	UInt32 busCount = 1;
	SP_CA_CHECK(err, @"Couldn't set mixer bus count", AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount)));
	SP_CA_CHECK(err, @"Couldn't set mixer volume", AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0));

	// Create PCM converter and get unit
	SP_CA_CHECK(err, @"Couldn't add converter node", AUGraphAddNode(audioProcessingGraph, &converterDescription, &inputConverterNode));
	SP_CA_CHECK(err, @"Couldn't get input unit", AUGraphNodeInfo(audioProcessingGraph, inputConverterNode, NULL, &inputConverterUnit));

	// Setup audio output
	if (![self setupAudioOutputFromBus:0 ofNode:mixerNode inGraph:audioProcessingGraph error:err])
		return NO;

	// Connect graph together
	if (![self connectOutputBus:0 ofNode:inputConverterNode toInputBus:0 ofNode:mixerNode inGraph:audioProcessingGraph error:err])
		return NO;

	// Set render callback
	AURenderCallbackStruct rcbs;
	rcbs.inputProc = AudioUnitRenderDelegateCallback;
	rcbs.inputProcRefCon = (__bridge void *)(self);
	SP_CA_CHECK(err, @"Couldn't add render callback", AUGraphSetNodeInputCallback(audioProcessingGraph, inputConverterNode, 0, &rcbs));

	// Finally, set the kAudioUnitProperty_MaximumFramesPerSlice of each unit
	// to 4096, to allow playback on iOS when the screen is locked.
	// Code based on http://developer.apple.com/library/ios/#qa/qa1606/_index.html

	UInt32 maxFramesPerSlice = 4096;
	SP_CA_CHECK(err, @"Couldn't set max frames per slice on input converter", AudioUnitSetProperty(inputConverterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice)));
	SP_CA_CHECK(err, @"Couldn't set max frames per slice on mixer", AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice)));

	// Init Queue
	SP_CA_CHECK(err, @"Couldn't initialize graph", AUGraphInitialize(audioProcessingGraph));
	SP_CA_CHECK(err, @"Couldn't update graph", AUGraphUpdate(audioProcessingGraph, NULL));

	// Apply properties and let's get going!
	[self startAudioQueue];
	[self applyAudioStreamDescriptionToInputUnit:inputFormat];
	[self applyVolumeToMixerAudioUnit:self.volume];

	return YES;
}

-(BOOL)connectOutputBus:(UInt32)sourceOutputBusNumber ofNode:(AUNode)sourceNode toInputBus:(UInt32)destinationInputBusNumber ofNode:(AUNode)destinationNode inGraph:(AUGraph)graph error:(NSError **)error {
	SP_CA_CHECK(error, @"Couldn't connect converter to mixer", AUGraphConnectNodeInput(graph, sourceNode, sourceOutputBusNumber, destinationNode, destinationInputBusNumber));
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

		UInt32 framesToAppend = self->framesSinceLastTimeUpdate;
		dispatch_async(dispatch_get_main_queue(), ^{
			NSTimeInterval duration = framesToAppend / self.inputAudioDescription.mSampleRate;
			[self.delegate coreAudioController:self didOutputAudioOfDuration:duration];
		});
		self->framesSinceLastTimeUpdate = 0;
	}

	return noErr;
}

#pragma mark - Output devices

#if !TARGET_OS_IPHONE

static OSStatus AOPropertyListenerProc(AudioObjectID inObjectID,
									   UInt32 inNumberAddresses,
									   const AudioObjectPropertyAddress inAddresses[],
									   void * inClientData) {

	SPCoreAudioController *controller = (__bridge SPCoreAudioController *)inClientData;

	for (NSUInteger x = 0; x < inNumberAddresses; x++) {
		if (inAddresses[x].mSelector == kAudioHardwarePropertyDevices) {

			dispatch_async(dispatch_get_main_queue(), ^{

				NSArray *newDevices = [controller queryOutputDevices:nil];
				controller.availableOutputDevices = newDevices;
				if (controller.currentOutputDevice != nil &&
					![controller.availableOutputDevices containsObject:controller.currentOutputDevice])
					controller.currentOutputDevice = nil;
			});

		}
	}
	return noErr;
}

-(NSUInteger)numberOfOutputBuffersInDevice:(AudioDeviceID)device {

	NSUInteger numberOfChannels = 0;

	AudioObjectPropertyAddress propertyAddress;
	propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
	propertyAddress.mScope = kAudioObjectPropertyScopeOutput;
	propertyAddress.mElement = kAudioObjectPropertyElementMaster;

	// Determine if the device is an output device (it is an output device if it has output channels)
	UInt32 dataSize = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(device, &propertyAddress, 0, NULL, &dataSize);
	if (status != kAudioHardwareNoError)
		return numberOfChannels;

	AudioBufferList *bufferList = malloc(dataSize);

	status = AudioObjectGetPropertyData(device, &propertyAddress, 0, NULL, &dataSize, bufferList);
	if(status == kAudioHardwareNoError)
		numberOfChannels = bufferList->mNumberBuffers;

	free(bufferList), bufferList = NULL;
	return numberOfChannels;
}

-(NSArray *)queryOutputDevices:(NSError **)error {

	AudioObjectPropertyAddress propertyAddress;
	propertyAddress.mSelector = kAudioHardwarePropertyDevices;
	propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
	propertyAddress.mElement = kAudioObjectPropertyElementMaster;

	UInt32 dataSize = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);
	if (status != kAudioHardwareNoError) {
		fillWithError(error, @"Couldn't get data size", status);
		return nil;
	}

	UInt32 deviceCount = (dataSize / sizeof(AudioDeviceID));
	AudioDeviceID *audioDevices = malloc(dataSize);

	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, audioDevices);
	if (status != kAudioHardwareNoError) {
		fillWithError(error, @"Couldn't get audio device count", status);
		free(audioDevices), audioDevices = NULL;
		return nil;
	}

	NSMutableArray *devices = [NSMutableArray arrayWithCapacity:deviceCount];

	// Iterate through all the devices and determine which are output-capable
	for (NSUInteger i = 0; i < deviceCount; i++) {

		if ([self numberOfOutputBuffersInDevice:audioDevices[i]] == 0)
			continue;

		SPCoreAudioDevice *device = [[SPCoreAudioDevice alloc] initWithDeviceId:audioDevices[i]];
		if (device)
			[devices addObject:device];
	}

	free(audioDevices), audioDevices = NULL;
	return [NSArray arrayWithArray:devices];
}

#endif

-(BOOL)setupAudioOutputFromBus:(UInt32)sourceOutputBusNumber ofNode:(AUNode)sourceNode inGraph:(AUGraph)graph error:(NSError *__autoreleasing *)error {

	if (outputNode != 0) {
		SP_CA_CHECK(error, @"Couldn't disconnect old output node", AUGraphDisconnectNodeInput(graph, outputNode, 0));
		SP_CA_CHECK(error, @"Couldn't remove old output node", AUGraphRemoveNode(graph, outputNode));
		SP_CA_CHECK(error, @"Couldn't update graph", AUGraphUpdate(graph, NULL));
		outputUnit = NULL;
		outputNode = 0;
	}

	// A description of the output device we're looking for.
	AudioComponentDescription outputDescription;
	outputDescription.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
	outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
#else
	outputDescription.componentSubType = self.currentOutputDevice == nil ? kAudioUnitSubType_DefaultOutput : kAudioUnitSubType_HALOutput;
#endif
	outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	outputDescription.componentFlags = 0;
	outputDescription.componentFlagsMask = 0;

	// Add audio output and get unit
	SP_CA_CHECK(error, @"Couldn't add output node", AUGraphAddNode(graph, &outputDescription, &outputNode));
	SP_CA_CHECK(error, @"Couldn't get output unit", AUGraphNodeInfo(graph, outputNode, NULL, &outputUnit));
	UInt32 maxFramesPerSlice = 4096;
	SP_CA_CHECK(error, @"Couldn't set max frames per slice on output", AudioUnitSetProperty(outputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice)));

	// Connect mixer to output
	SP_CA_CHECK(error, @"Couldn't connect mixer to output", AUGraphConnectNodeInput(graph, sourceNode, sourceOutputBusNumber, outputNode, 0));

#if !TARGET_OS_IPHONE
	if (self.currentOutputDevice != nil) {
		if (![self applyOutputDeviceWithUIDToAudioOutput:self.currentOutputDevice.UID error:error])
			return NO;
	}
#endif

	SP_CA_CHECK(error, @"Couldn't update graph", AUGraphUpdate(graph, NULL));
	return YES;
}

#if !TARGET_OS_IPHONE

-(BOOL)applyOutputDeviceWithUIDToAudioOutput:(NSString *)uid error:(NSError **)error {

	if (outputUnit == NULL) {
		fillWithError(error, @"Can't apply output device to NULL output unit", 0);
		return NO;
	}

	AudioDeviceID deviceId = kAudioObjectUnknown;
	
	for (SPCoreAudioDevice *device in self.availableOutputDevices)
		if ([device.UID isEqualToString:uid])
			deviceId = device.deviceId;
	
	if (deviceId == kAudioObjectUnknown) {
		fillWithError(error, @"Can't find output device", deviceId);
		return NO;
	}
	
	//set AudioDeviceID of desired device
	SP_CA_CHECK(error, @"Can't apply new output device to audio unit",
				AudioUnitSetProperty(outputUnit,
									 kAudioOutputUnitProperty_CurrentDevice,
									 kAudioUnitScope_Output,
									 0,
									 &deviceId,
									 sizeof(deviceId)));
	
	return YES;
}

#endif

@end
