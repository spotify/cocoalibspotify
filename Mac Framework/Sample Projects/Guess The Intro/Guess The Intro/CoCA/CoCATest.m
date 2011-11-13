//
//  CoCATest.m
//  CoCA
//
//  Created by Joachim Bengtsson on 2008-02-10.
//  Copyright 2008 Joachim Bengtsson. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import "CoCA.h"

FILE *debugraw;

@interface Foo : NSObject <CoCAAudioUnitRenderDelegate> {
    Float64 f;
@public
    Float64 pitch;
    Float64 volume;
}
@end
@implementation Foo
-(OSStatus)audioUnit:(CoCAAudioUnit*)audioUnit
     renderWithFlags:(AudioUnitRenderActionFlags*)ioActionFlags
                  at:(const AudioTimeStamp*)inTimeStamp
               onBus:(UInt32)inBusNumber
          frameCount:(UInt32)inNumberFrames
           audioData:(AudioBufferList *)ioData;
{
    Float64 startF = f;
    for(int bufferIndex = 0; bufferIndex < ioData->mNumberBuffers; bufferIndex++) {
        f = startF;
        AudioBuffer *buffer = &(ioData->mBuffers[bufferIndex]);
        
        float *channelBuffer = (float*)(buffer->mData);
        for(int sample = 0; sample < inNumberFrames; sample++) {
            channelBuffer[sample] = sinf(f)*volume;
            f += (pitch*2*M_PI)/44100;
        }
    }
    //fwrite(ioData->mBuffers[0].mData, 1, ioData->mBuffers[0].mDataByteSize, debugraw);
    return noErr;
}

-(void)setPitchWithMouseCursorPosition;
{
    volume = [NSEvent mouseLocation].y / [[NSScreen mainScreen] frame].size.height;
    pitch = [NSEvent mouseLocation].x;
}
@end

int main() {
    NSAutoreleasePool *p = [NSAutoreleasePool new];
    CoCAAudioUnit *unit = [CoCAAudioUnit defaultOutputUnit];
    debugraw = fopen("debug.raw", "w");
    Foo *foo= [Foo new];
    foo->pitch = 440;
    foo->volume = 0.5;
    [NSTimer scheduledTimerWithTimeInterval:0.01 target:foo selector:@selector(setPitchWithMouseCursorPosition) userInfo:nil repeats:YES];
    [unit setRenderDelegate:foo];
    [unit setup];
    [unit start];
    
    NSLog(@"%@", unit);
    
    while(1) {
        NSAutoreleasePool *p = [NSAutoreleasePool new];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
        [p release];
    }
    [p release];
    return 0;
}