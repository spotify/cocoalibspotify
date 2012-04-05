//
//  Guess_The_IntroAppDelegate.m
//  Guess The Intro
//
//  Created by Daniel Kennett on 05/05/2011.
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

#import "Guess_The_IntroAppDelegate.h"
#import "SPArrayExtensions.h"
#import <QuartzCore/QuartzCore.h>

#error Please get an appkey.c file from developer.spotify.com and remove this error before building.
#import "appkey.c"

static NSUInteger const kLoadingTimeout = 10;
static NSTimeInterval const kRoundDuration = 20.0;
static NSTimeInterval const kGameDuration = 60 * 5; // 5 mins
static NSTimeInterval const kGameCountdownThreshold = 30.0;

@implementation Guess_The_IntroAppDelegate

@synthesize userNameField;
@synthesize passwordField;
@synthesize playlistNameField;
@synthesize loginView;
@synthesize window;
@synthesize oneButton;
@synthesize fourButton;
@synthesize countdownProgress;
@synthesize threeButton;
@synthesize twoButton;

@synthesize playbackManager;
@synthesize playlist;

@synthesize firstSuggestion;
@synthesize secondSuggestion;
@synthesize thirdSuggestion;
@synthesize fourthSuggestion;

@synthesize canPushOne;
@synthesize canPushTwo;
@synthesize canPushThree;
@synthesize canPushFour;

@synthesize userTopList;
@synthesize regionTopList;

@synthesize multiplier;
@synthesize score;
@synthesize roundStartDate;
@synthesize gameStartDate;
@synthesize trackPool;
@synthesize roundTimer;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	
	[SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:&g_appkey length:g_appkey_size]
											   userAgent:@"com.spotify.GuessTheIntro"
												   error:nil];
	 
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithBool:YES], @"CreatePlaylist",
															 [NSNumber numberWithInteger:1], @"HighMultiplier",
															 nil]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	// Insert code here to initialize your application
	
	srandom((unsigned int)time(NULL));
	
	[[SPSession sharedSession] setDelegate:self];
	
	self.playbackManager = [[SPPlaybackManager alloc] initWithPlaybackSession:[SPSession sharedSession]];
	self.playbackManager.delegate = self;
	
	self.multiplier = 1;
	
	[self.loginView.layer setBackgroundColor:CGColorCreateGenericGray(0.93, 1.0)];
	
	self.loginView.frame = ((NSView *)self.window.contentView).bounds;
	[self.window.contentView addSubview:self.loginView];
	
	if ([[self.userNameField stringValue] length] > 0)
		[self.passwordField becomeFirstResponder];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	[self.playlistNameField setStringValue:[NSString stringWithFormat:@"Guess The Intro: %@", [formatter stringFromDate:[NSDate date]]]];
	
	[self.window center];
	[self.window orderFrontRegardless];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if ([SPSession sharedSession].connectionState == SP_CONNECTION_STATE_LOGGED_OUT ||
		[SPSession sharedSession].connectionState == SP_CONNECTION_STATE_UNDEFINED) 
		return NSTerminateNow;
	
	[[SPSession sharedSession] logout];
	return NSTerminateLater;
}

-(void)windowWillClose:(NSNotification *)notification {
	[NSApp terminate:self];
}

- (IBAction)login:(id)sender {
	
	// Invoked by clicking the "Login" button in the UI.
	
	if ([[userNameField stringValue] length] > 0 && 
		[[passwordField stringValue] length] > 0) {
		
		[[SPSession sharedSession] attemptLoginWithUserName:[userNameField stringValue]
												   password:[passwordField stringValue]
										rememberCredentials:NO];
	} else {
		NSBeep();
	}
}

#pragma mark -
#pragma mark SPSession Delegates

-(void)sessionDidLoginSuccessfully:(SPSession *)aSession; {
	
	// Invoked by SPSession after a successful login.
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.75];
	
	[[self.loginView animator] setAlphaValue:0.0];
	
	[NSAnimationContext endGrouping];
	
	[[self loginView] performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:1.0];
	
	[self.countdownProgress setIndeterminate:YES];
	[self.countdownProgress startAnimation:nil];
	
	self.regionTopList = [SPToplist toplistForLocale:aSession.locale
										   inSession:aSession];
	self.userTopList = [SPToplist toplistForCurrentUserInSession:aSession];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CreatePlaylist"])
		self.playlist = [[[SPSession sharedSession] userPlaylists] createPlaylistWithName:self.playlistNameField.stringValue];
	
	[self waitAndFillTrackPool];
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error; {
    
	// Invoked by SPSession after a failed login.
	
    [NSApp presentError:error
         modalForWindow:self.window
               delegate:nil
     didPresentSelector:nil
            contextInfo:nil];
}

-(void)sessionDidLogOut:(SPSession *)aSession; {
	[[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
}

-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error; {}
-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage; {}
-(void)sessionDidChangeMetadata:(SPSession *)aSession; {}

-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage; {

	[[NSAlert alertWithMessageText:aMessage
					 defaultButton:@"OK"
				   alternateButton:@""
					   otherButton:@""
		 informativeTextWithFormat:@"This message was sent to you from the Spotify service."] runModal];
}


#pragma mark -
#pragma mark Game UI Actions

- (IBAction)guessOne:(id)sender {
	
	self.canPushOne = NO;
	[self guessTrack:self.firstSuggestion];
}

- (IBAction)guessTwo:(id)sender {
	
	self.canPushTwo = NO;
	[self guessTrack:self.secondSuggestion];
}

- (IBAction)guessThree:(id)sender {
	
	self.canPushThree = NO;
	[self guessTrack:self.thirdSuggestion];
}

- (IBAction)guessFour:(id)sender {
	
	self.canPushFour = NO;
	[self guessTrack:self.fourthSuggestion];
}

#pragma mark -
#pragma mark Finding Tracks

-(void)waitAndFillTrackPool {
	
	// It can take a while for playlists to load, especially on a large account.
	// Here, we go through things we're interested in to see if they're loaded.
	// If they're not loaded after five attempts, we assume enough will be loaded
	// to provide a reasonable pool of tracks and move on.
	
	if (![[[SPSession sharedSession] userPlaylists] isLoaded]) {
		loginAttempts++;
		
		if (loginAttempts < kLoadingTimeout) {
			[self performSelector:_cmd withObject:nil afterDelay:1.0];
			return;
		}
	}
	
	SPPlaylist *starred = [[SPSession sharedSession] starredPlaylist];
	SPPlaylist *inbox = [[SPSession sharedSession] inboxPlaylist];
	
	if (starred.isLoaded == NO || inbox.isLoaded == NO || self.regionTopList.isLoaded == NO || self.userTopList.isLoaded == NO) {
		loginAttempts++;
		
		if (loginAttempts < kLoadingTimeout) {
			[self performSelector:_cmd withObject:nil afterDelay:1.0];
			return;
		}
	}
	
	NSMutableArray *playlistPool = [NSMutableArray arrayWithObjects:starred, inbox, nil];
	
	for (id playlistOrFolder in [[SPSession sharedSession] userPlaylists].playlists) {
		if ([playlistOrFolder isKindOfClass:[SPPlaylist class]]) {
			[playlistPool addObject:(SPPlaylist *)playlistOrFolder];
		} else {
			[playlistPool addObjectsFromArray:[self playlistsInFolder:(SPPlaylistFolder *)playlistOrFolder]];
		}
	}
	
	for (SPPlaylist *aPlaylist in playlistPool) {
		if (aPlaylist.isLoaded == NO && aPlaylist.isUpdating == NO) {
			loginAttempts++;
			
			if (loginAttempts < kLoadingTimeout) {
				[self performSelector:_cmd withObject:nil afterDelay:1.0];
				return;
			}
		}
	}
	
	NSMutableArray *potentialTrackPool = [NSMutableArray arrayWithArray:[self tracksFromPlaylistItems:[playlistPool valueForKeyPath:@"@unionOfArrays.items"]]];
	[potentialTrackPool addObjectsFromArray:[self tracksFromPlaylistItems:starred.items]];
	[potentialTrackPool addObjectsFromArray:[self tracksFromPlaylistItems:inbox.items]];
	[potentialTrackPool addObjectsFromArray:self.regionTopList.tracks];
	[potentialTrackPool addObjectsFromArray:self.userTopList.tracks];
	
	NSMutableArray *theTrackPool = [NSMutableArray arrayWithCapacity:[potentialTrackPool count]];
	
	for (SPTrack *aTrack in potentialTrackPool) {
		if (aTrack.availability == SP_TRACK_AVAILABILITY_AVAILABLE && [aTrack.name length] > 0)
			[theTrackPool addObject:aTrack];
	}
	
	SPTrack *rickRollingNeverGetsOld = [[SPSession sharedSession] 
										trackForURL:[NSURL URLWithString:@"spotify:track:6JEK0CvvjDjjMUBFoXShNZ"]];
	if (rickRollingNeverGetsOld != nil)
		[theTrackPool addObject:rickRollingNeverGetsOld];
	
	self.trackPool = [NSMutableArray arrayWithArray:[[NSSet setWithArray:theTrackPool] allObjects]];
	// ^ Thin out duplicates.
	
	[self startNewRound];
}

-(NSArray *)playlistsInFolder:(SPPlaylistFolder *)aFolder {
	
	NSMutableArray *playlists = [NSMutableArray arrayWithCapacity:[[aFolder playlists] count]];
	
	for (id playlistOrFolder in aFolder.playlists) {
		if ([playlistOrFolder isKindOfClass:[SPPlaylist class]]) {
			[playlists addObject:playlistOrFolder];
		} else {
			[playlists addObjectsFromArray:[self playlistsInFolder:playlistOrFolder]];
		}
	}
	return [NSArray arrayWithArray:playlists];
}

-(NSArray *)tracksFromPlaylistItems:(NSArray *)items {
	
	NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:items.count];
	
	for (SPPlaylistItem *anItem in items) {
		if (anItem.itemClass == [SPTrack class]) {
			[tracks addObject:anItem.item];
		}
	}
	
	return [NSArray arrayWithArray:tracks];
}

-(SPTrack *)trackForUserToGuessWithAlternativeOne:(SPTrack **)alternative two:(SPTrack **)anotherAlternative three:(SPTrack **)aThirdAlternative {
	
	SPTrack *theOne = nil;
	while ((!theOne.availability == SP_TRACK_AVAILABILITY_AVAILABLE) && theOne.duration < kRoundDuration) {
		theOne = [self.trackPool randomObject];
		[self.trackPool removeObject:theOne];
		
		if ([self.trackPool count] < 3) {
			// Eeek! Can't fill alternatives!
			if (alternative != NULL)
				*alternative = nil;
			if (anotherAlternative != NULL)
				*anotherAlternative = nil;
			if (aThirdAlternative != NULL)
				*aThirdAlternative = nil;
			
			return nil;
		}
	}	
	
	// Make sure we don't choose the same one more than once
	
	if (alternative != NULL) {
		*alternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*alternative];
	}
	if (anotherAlternative != NULL) {
		*anotherAlternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*anotherAlternative];
	}
	if (aThirdAlternative != NULL) {
		*aThirdAlternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*aThirdAlternative];
	}
	
	if (alternative != NULL)
		[self.trackPool addObject:*alternative];
	if (anotherAlternative != NULL)
		[self.trackPool addObject:*anotherAlternative];
	if (aThirdAlternative != NULL)
		[self.trackPool addObject:*aThirdAlternative];
	
	return theOne;
}

#pragma mark -
#pragma mark Game Logic


-(NSTimeInterval)gameTimeRemaining {
	if (self.gameStartDate == nil)
		return 0.0;
	return kGameDuration -[[NSDate date] timeIntervalSinceDate:self.gameStartDate];
}

-(NSTimeInterval)roundTimeRemaining {
	if (self.roundStartDate == nil)
		return 0.0;
	return kRoundDuration -[[NSDate date] timeIntervalSinceDate:self.roundStartDate];
}

-(NSUInteger)currentRoundScore {
	if (self.roundStartDate == nil)
		return 0.0;
	NSTimeInterval remainingTime = [self roundTimeRemaining];
	return MAX(remainingTime * remainingTime * self.multiplier, 1.0);
}

+(NSSet *)keyPathsForValuesAffectingHideCountdown {
	return [NSSet setWithObject:@"gameTimeRemaining"];
}

-(BOOL)hideCountdown {
	return (self.gameStartDate == nil || self.gameTimeRemaining > kGameCountdownThreshold);
}

#pragma mark -

-(void)roundTimerDidTick:(NSTimer *)aTimer {
	
	if (self.roundTimeRemaining <= 0.0)
		[self roundTimeExpired];
	
	if (self.gameTimeRemaining <= 0.0)
		[self gameOverWithReason:@"Out of time!"];
	
	[self willChangeValueForKey:@"roundTimeRemaining"];
	[self didChangeValueForKey:@"roundTimeRemaining"];
	[self willChangeValueForKey:@"gameTimeRemaining"];
	[self didChangeValueForKey:@"gameTimeRemaining"];
	[self willChangeValueForKey:@"currentRoundScore"];
	[self didChangeValueForKey:@"currentRoundScore"];
}

-(void)roundTimeExpired {
	NSBeep();
	self.multiplier = 1;
	[self startNewRound];
}

#pragma mark -

-(void)guessTrack:(SPTrack *)itsTotallyThisOne {

	if (self.playbackManager.currentTrack == nil || itsTotallyThisOne == nil)
		return;
	
	if (itsTotallyThisOne == self.playbackManager.currentTrack) {
		self.score += self.currentRoundScore;
		
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"HighScore"] < self.score)
			[[NSUserDefaults standardUserDefaults] setInteger:self.score forKey:@"HighScore"];
		
		self.multiplier++;
		
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"HighMultiplier"] < self.multiplier)
			[[NSUserDefaults standardUserDefaults] setInteger:self.multiplier forKey:@"HighMultiplier"];
		
		[self startNewRound];
	} else {
		NSBeep();
		self.multiplier = 1;
		self.roundStartDate = [NSDate dateWithTimeInterval:-(kRoundDuration / 4) sinceDate:self.roundStartDate];
	}
}

-(void)startNewRound {
	
	if (self.playbackManager.currentTrack != nil)
		[self.playlist.items addObject:self.playbackManager.currentTrack];
	
	// Starting a new round means resetting, selecting tracks then starting the timer again 
	// when the audio starts playing.
	
	self.playbackManager.isPlaying = NO;
	self.firstSuggestion = nil;
	self.secondSuggestion = nil;
	self.thirdSuggestion = nil;
	self.fourthSuggestion = nil;
	self.roundStartDate = nil;
	
	[self.countdownProgress setIndeterminate:YES];
	
	[self.roundTimer invalidate];
	self.roundTimer = nil;
	
	SPTrack *one = nil;
	SPTrack *two = nil;
	SPTrack *three = nil;
	SPTrack *theOne = [self trackForUserToGuessWithAlternativeOne:&one two:&two three:&three];
	
	if (theOne != nil) {
		
		NSMutableArray *array = [NSMutableArray arrayWithObjects:theOne, one, two, three, nil];
		self.firstSuggestion = [array randomObject];
		[array removeObject:self.firstSuggestion];
		self.secondSuggestion = [array randomObject];
		[array removeObject:self.secondSuggestion];
		self.thirdSuggestion = [array randomObject];
		[array removeObject:self.thirdSuggestion];
		self.fourthSuggestion = [array randomObject];
		[array removeObject:self.fourthSuggestion];
		
		//Disable buttons until playback starts
		self.canPushOne = NO;
		self.canPushTwo = NO;
		self.canPushThree = NO;
		self.canPushFour = NO;
		
		[self startPlaybackOfTrack:theOne];
		
	} else {
		
		[self gameOverWithReason:@"Out of tracks!"];
	}
}

-(void)gameOverWithReason:(NSString *)reason {
	
	self.playbackManager.isPlaying = NO;
	self.firstSuggestion = nil;
	self.secondSuggestion = nil;
	self.thirdSuggestion = nil;
	self.fourthSuggestion = nil;
	self.roundStartDate = nil;
	self.gameStartDate = nil;
	
	[self.countdownProgress setIndeterminate:YES];
	
	[self.roundTimer invalidate];
	self.roundTimer = nil;

	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setFormat:@"#,###,###,###,##0"];
	
	NSInteger result = [[NSAlert alertWithMessageText:reason
					 defaultButton:@"Again!"
				   alternateButton:@"Quit"
					   otherButton:@""
		 informativeTextWithFormat:[NSString stringWithFormat:@"You scored %@ points!", 
									[formatter stringFromNumber:[NSNumber numberWithInteger:self.score]]]]
	 runModal];
	
	if (result == NSAlertDefaultReturn) {
		self.score = 0;
		self.multiplier = 1;
		[self waitAndFillTrackPool];
	} else {
		[NSApp terminate:self];
	}
}

#pragma mark -
#pragma mark Playback

- (void)startPlaybackOfTrack:(SPTrack *)aTrack {
	
	if (aTrack != nil) {
		
		if (!aTrack.isLoaded) {
			// Since we're trying to play a brand new track that may not be loaded, 
			// we may have to wait for a moment before playing. Tracks that are present 
			// in the user's "library" (playlists, starred, inbox, etc) are automatically loaded
			// on login. All this happens on an internal thread, so we'll just try again in a moment.
			[self performSelector:@selector(startPlaybackOfTrack:) withObject:aTrack afterDelay:0.1];
			return;
		}
	
		NSError *error = nil;
		
		if (![self.playbackManager playTrack:aTrack error:&error]) {
			[self.window presentError:error];
		}
		return;
	}
	NSBeep();
}

-(void)playbackManagerWillStartPlayingAudio:(SPPlaybackManager *)aPlaybackManager {

	[self.countdownProgress setIndeterminate:NO];
	
	self.roundStartDate = [NSDate date];
	if (self.gameStartDate == nil)
		self.gameStartDate = roundStartDate;
	
	self.roundTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
													   target:self
													 selector:@selector(roundTimerDidTick:)
													 userInfo:nil
													  repeats:YES];
	
	self.canPushOne = YES;
	self.canPushTwo = YES;
	self.canPushThree = YES;
	self.canPushFour = YES;

}

@end
