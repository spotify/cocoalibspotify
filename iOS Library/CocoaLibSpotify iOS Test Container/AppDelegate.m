//
//  AppDelegate.m
//  CocoaLibSpotify iOS Test Container
//
//  Created by Daniel Kennett on 22/05/2012.
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
#import "ViewController.h"

#import "SPSessionTests.h"
#import "SPMetadataTests.h"
#import "SPSearchTests.h"
#import "SPPostTracksToInboxTests.h"
#import "SPAudioDeliveryTests.h"
#import "SPSessionTeardownTests.h"
#import "SPPlaylistTests.h"
#import "SPConcurrencyTests.h"
#import "SPOfflineSyncTests.h"

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
@property (nonatomic, strong) SPTests *offlineSyncTests;
@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize sessionTests;
@synthesize metadataTests;
@synthesize searchTests;
@synthesize inboxTests;
@synthesize audioTests;
@synthesize teardownTests;
@synthesize playlistTests;
@synthesize concurrencyTests;
@synthesize offlineSyncTests;

-(void)completeTestsWithPassCount:(NSUInteger)passCount failCount:(NSUInteger)failCount {
	printf("**** Completed %lu tests with %lu passes and %lu failures ****\n", (unsigned long)(passCount + failCount), (unsigned long)passCount, (unsigned long)failCount);
	[self pushColorToStatusServer:failCount > 0 ? [UIColor redColor] : [UIColor greenColor]];
	exit(failCount > 0 ? EXIT_FAILURE : EXIT_SUCCESS);
}

-(void)pushColorToStatusServer:(UIColor *)color {
	
	NSString *statusServerAddress = [[NSUserDefaults standardUserDefaults] stringForKey:kTestStatusServerUserDefaultsKey];
	if (statusServerAddress.length == 0) return;
	
	CGFloat red = 0.0;
	CGFloat green = 0.0;
	CGFloat blue = 0.0;
	
	[color getRed:&red green:&green blue:&blue alpha:NULL];
	
	NSString *requestUrlString = [NSString stringWithFormat:@"http://%@/push-color?red=%lu&green=%lu&blue=%lu",
								  statusServerAddress,
								  (NSUInteger)red * 255,
								  (NSUInteger)green * 255,
								  (NSUInteger)blue * 255];
	
	NSURL *requestUrl = [NSURL URLWithString:requestUrlString];							  
	NSURLRequest *request = [NSURLRequest requestWithURL:requestUrl 
											 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
										 timeoutInterval:1.0];
	
	[NSURLConnection sendSynchronousRequest:request
						  returningResponse:nil
									  error:nil];
	
}

#pragma mark - Running Tests

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil];
	} else {
	    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPad" bundle:nil];
	}
	self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
	[self pushColorToStatusServer:[UIColor yellowColor]];
	
	// Insert code here to initialize your application
	self.sessionTests = [SPSessionTests new];
	
	__block NSUInteger totalPassCount = 0;
	__block NSUInteger totalFailCount = 0;
	
	[self.sessionTests runTests:^(NSUInteger sessionPassCount, NSUInteger sessionFailCount) {
		
		totalPassCount += sessionPassCount;
		totalFailCount += sessionFailCount;
		
		self.concurrencyTests = [SPConcurrencyTests new];
		[self.concurrencyTests runTests:^(NSUInteger concurrencyPassCount, NSUInteger concurrencyFailCount) {
			
			totalPassCount += concurrencyPassCount;
			totalFailCount += concurrencyFailCount;
			
			self.playlistTests = [SPPlaylistTests new];
			[self.playlistTests runTests:^(NSUInteger playlistPassCount, NSUInteger playlistFailCount) {
				
				totalPassCount += playlistPassCount;
				totalFailCount += playlistFailCount;
				
				self.audioTests = [SPAudioDeliveryTests new];
				[self.audioTests runTests:^(NSUInteger audioPassCount, NSUInteger audioFailCount) {
					
					totalPassCount += audioPassCount;
					totalFailCount += audioFailCount;
					
					self.searchTests = [SPSearchTests new];
					[self.searchTests runTests:^(NSUInteger searchPassCount, NSUInteger searchFailCount) {
						
						totalPassCount += searchPassCount;
						totalFailCount += searchFailCount;
						
						self.inboxTests = [SPPostTracksToInboxTests new];
						[self.inboxTests runTests:^(NSUInteger inboxPassCount, NSUInteger inboxFailCount) {
							
							totalPassCount += inboxPassCount;
							totalFailCount += inboxFailCount;
							
							self.metadataTests = [SPMetadataTests new];
							[self.metadataTests runTests:^(NSUInteger metadataPassCount, NSUInteger metadataFailCount) {
								
								totalPassCount += metadataPassCount;
								totalFailCount += metadataFailCount;
								
                self.offlineSyncTests = [SPOfflineSyncTests new];
                [self.offlineSyncTests runTests:^(NSUInteger offlineSyncPassCount, NSUInteger offlineSyncFailCount) {
                  
                  totalPassCount += offlineSyncPassCount;
                  totalFailCount += offlineSyncFailCount;
                  
                  self.teardownTests = [SPSessionTeardownTests new];
                  [self.teardownTests runTests:^(NSUInteger teardownPassCount, NSUInteger teardownFailCount) {
                    
                    totalPassCount += teardownPassCount;
                    totalFailCount += teardownFailCount;
                    
                    [self completeTestsWithPassCount:totalPassCount failCount:totalFailCount];
                    
                  }];
                }];
							}];
						}];
					}];
				}];
			}];
		}];
	}];
	
	return YES;
}

@end
