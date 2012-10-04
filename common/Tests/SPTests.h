//
//  SPTests.h
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

#import <Foundation/Foundation.h>

typedef enum {
	kTestStateWaiting,
	kTestStateRunning,
	kTestStatePassed,
	kTestStateFailed
} SPTestState;

@interface SPTestUIPlaceholder : NSObject

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite) SPTestState state;

@end

@interface SPTests : NSObject

#define SPPassTest() [self passTest:_cmd]; return;

#define SPTestAssert(condition, desc, ...) \
if (!(condition)) {	\
[self failTest:_cmd format:(desc), ##__VA_ARGS__]; \
return; \
}

#define SPOtherTestAssert(selector, condition, desc, ...) \
if (!(condition)) {	\
[self failTest:selector format:(desc), ##__VA_ARGS__]; \
return; \
}

-(void)passTest:(SEL)testSelector;
-(void)failTest:(SEL)testSelector format:(NSString *)format, ...;

-(void)runTests:(void (^)(NSUInteger passCount, NSUInteger failCount))block;

@property (nonatomic, readwrite, copy) NSArray *uiPlaceholders;

@end
