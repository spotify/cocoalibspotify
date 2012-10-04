//
//  AppDelegate.m
//  CocoaLibSpotify Test Container
//
//  Created by Daniel Kennett on 09/05/2012.
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

#import "AppDelegate.h"
#import "SPSessionTests.h"
#import "SPMetadataTests.h"
#import "SPSearchTests.h"
#import "SPPostTracksToInboxTests.h"
#import "SPAudioDeliveryTests.h"
#import "SPSessionTeardownTests.h"
#import "SPPlaylistTests.h"
#import "SPConcurrencyTests.h"

static NSString * const kTestStatusServerUserDefaultsKey = @"StatusColorServer";

@interface AppDelegate ()
@property (nonatomic, strong) SPTests *sessionTests;
@property (nonatomic, strong) SPTests *metadataTests;
@property (nonatomic, strong) SPTests *searchTests;
@property (nonatomic, strong) SPTests *inboxTests;
@property (nonatomic, strong) SPTests *audioTests;
@property (nonatomic, strong) SPTests *teardownTests;
@property (nonatomic, strong) SPTests *playlistTests;
@property (nonatomic, strong) SPTests *concurrencyTests;
@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize sessionTests;
@synthesize metadataTests;
@synthesize searchTests;
@synthesize inboxTests;
@synthesize audioTests;
@synthesize teardownTests;
@synthesize playlistTests;
@synthesize concurrencyTests;

-(void)completeTestsWithPassCount:(NSUInteger)passCount failCount:(NSUInteger)failCount {
	printf("**** Completed %lu tests with %lu passes and %lu failures ****\n", passCount + failCount, passCount, failCount);
	[self pushColorToStatusServer:failCount > 0 ? [NSColor redColor] : [NSColor greenColor]];
	exit(failCount > 0 ? EXIT_FAILURE : EXIT_SUCCESS);
}

-(void)pushColorToStatusServer:(NSColor *)color {
	
	NSString *statusServerAddress = [[NSUserDefaults standardUserDefaults] stringForKey:kTestStatusServerUserDefaultsKey];
	if (statusServerAddress.length == 0) return;
	
	NSColor *colorToSend = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
	
	NSString *requestUrlString = [NSString stringWithFormat:@"http://%@/push-color?red=%lu&green=%lu&blue=%lu",
								  statusServerAddress,
								  (NSUInteger)colorToSend.redComponent * 255,
								  (NSUInteger)colorToSend.greenComponent * 255,
								  (NSUInteger)colorToSend.blueComponent * 255];
	
	NSURL *requestUrl = [NSURL URLWithString:requestUrlString];							  
	NSURLRequest *request = [NSURLRequest requestWithURL:requestUrl 
											 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
										 timeoutInterval:1.0];
	
	[NSURLConnection sendSynchronousRequest:request
						  returningResponse:nil
									  error:nil];
	
}

#pragma mark - Running Tests

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self pushColorToStatusServer:[NSColor yellowColor]];
	
	// Make sure we have a clean cache before starting.
	NSString *aUserAgent = @"com.spotify.CocoaLSUnitTests";

	// Find the application support directory for settings
	NSString *applicationSupportDirectory = nil;
	NSArray *potentialDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
																		NSUserDomainMask,
																		YES);

	if ([potentialDirectories count] > 0) {
		applicationSupportDirectory = [[potentialDirectories objectAtIndex:0] stringByAppendingPathComponent:aUserAgent];
	} else {
		applicationSupportDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:aUserAgent];
	}

	if ([[NSFileManager defaultManager] fileExistsAtPath:applicationSupportDirectory]) {
		printf("Application support directory exists, deleting… ");
		if (![[NSFileManager defaultManager] removeItemAtPath:applicationSupportDirectory error:nil])
			printf("failed.\n");
		else
			printf("done.\n");
	}

	// Find the caches directory for cache
	NSString *cacheDirectory = nil;
	NSArray *potentialCacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
																			 NSUserDomainMask,
																			 YES);

	if ([potentialCacheDirectories count] > 0) {
		cacheDirectory = [[potentialCacheDirectories objectAtIndex:0] stringByAppendingPathComponent:aUserAgent];
	} else {
		cacheDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:aUserAgent];
	}

	if ([[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory]) {
		printf("Cache directory exists, deleting… ");
		if (![[NSFileManager defaultManager] removeItemAtPath:cacheDirectory error:nil])
			printf("failed.\n");
		else
			printf("done.\n");
	}

	self.sessionTests = [SPSessionTests new];
	self.concurrencyTests = [SPConcurrencyTests new];
	self.playlistTests = [SPPlaylistTests new];
	self.audioTests = [SPAudioDeliveryTests new];
	self.searchTests = [SPSearchTests new];
	self.inboxTests = [SPPostTracksToInboxTests new];
	self.metadataTests = [SPMetadataTests new];
	self.teardownTests = [SPSessionTeardownTests new];

	NSArray *tests = @[self.sessionTests, self.concurrencyTests, self.playlistTests, self.audioTests, self.searchTests,
	self.inboxTests, self.metadataTests, self.teardownTests];

	__block NSUInteger totalPassCount = 0;
	__block NSUInteger totalFailCount = 0;
	__block NSUInteger currentTestIndex = 0;

	__block void (^runNextTest)(void) = ^ {

		if (currentTestIndex >= tests.count) {
			[self completeTestsWithPassCount:totalPassCount failCount:totalFailCount];
			return;
		}

		SPTests *testsToRun = tests[currentTestIndex];
		[testsToRun runTests:^(NSUInteger passCount, NSUInteger failCount) {
			totalPassCount += passCount;
			totalFailCount += failCount;

			//Special-case the first test suite since libspotify currently crashes a lot
			//if you call certain APIs without being logged in.
			if (currentTestIndex == 0 && totalFailCount > 0) {
				[self completeTestsWithPassCount:totalPassCount failCount:totalFailCount];
				return;
			}

			currentTestIndex++;
			runNextTest();
		}];
	};

	runNextTest();
}

@end
