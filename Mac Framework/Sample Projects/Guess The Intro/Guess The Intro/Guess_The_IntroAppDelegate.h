//
//  Guess_The_IntroAppDelegate.h
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

#import <Cocoa/Cocoa.h>
#import <CocoaLibSpotify/CocoaLibSpotify.h>
#import "SPPlaybackManager.h"

@interface Guess_The_IntroAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, SPSessionDelegate, SPPlaybackManagerDelegate> {
	
@private
	
	NSTextField *userNameField;
	NSSecureTextField *passwordField;
	NSTextField *playlistNameField;
	NSView *loginView;
	
	NSWindow *window;
	NSButton *oneButton;
	NSButton *twoButton;
	NSButton *threeButton;
	NSButton *fourButton;
	NSProgressIndicator *countdownProgress;
	
	NSUInteger loginAttempts;
	
	SPPlaylist *playlist;
	
	SPPlaybackManager *playbackManager;
	
	SPToplist *regionTopList;
	SPToplist *userTopList;
	
	NSMutableArray *trackPool;
	SPTrack *firstSuggestion;
	SPTrack *secondSuggestion;
	SPTrack *thirdSuggestion;
	SPTrack *fourthSuggestion;
	
	BOOL canPushOne;
	BOOL canPushTwo;
	BOOL canPushThree;
	BOOL canPushFour;
	
	NSTimer *roundTimer;
	
	NSUInteger multiplier; // Reset every time a wrong guess is made.
	NSUInteger score; // The current score
	NSDate *roundStartDate; // The time at which the current round started. Round score = (kRoundTime - seconds from this date) * multiplier.
	NSDate *gameStartDate;
}

@property (assign) IBOutlet NSTextField *userNameField;
@property (assign) IBOutlet NSSecureTextField *passwordField;
@property (assign) IBOutlet NSTextField *playlistNameField;
@property (assign) IBOutlet NSView *loginView;

@property (nonatomic, readwrite, retain) SPPlaybackManager *playbackManager;

@property (nonatomic, readwrite, retain) SPPlaylist	*playlist;

- (IBAction)login:(id)sender;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *oneButton;
@property (assign) IBOutlet NSButton *twoButton;
@property (assign) IBOutlet NSButton *threeButton;
@property (assign) IBOutlet NSButton *fourButton;
@property (assign) IBOutlet NSProgressIndicator *countdownProgress;

@property (nonatomic, retain, readwrite) SPToplist *regionTopList;
@property (nonatomic, retain, readwrite) SPToplist *userTopList;

@property (nonatomic, retain, readwrite) SPTrack *firstSuggestion;
@property (nonatomic, retain, readwrite) SPTrack *secondSuggestion;
@property (nonatomic, retain, readwrite) SPTrack *thirdSuggestion;
@property (nonatomic, retain, readwrite) SPTrack *fourthSuggestion;

@property (nonatomic, readwrite) BOOL canPushOne;
@property (nonatomic, readwrite) BOOL canPushTwo;
@property (nonatomic, readwrite) BOOL canPushThree;
@property (nonatomic, readwrite) BOOL canPushFour;

@property (nonatomic, readwrite) NSUInteger multiplier;
@property (nonatomic, readwrite) NSUInteger score;
@property (nonatomic, readwrite, copy) NSDate *roundStartDate;
@property (nonatomic, readwrite, copy) NSDate *gameStartDate;
@property (nonatomic, readwrite, retain) NSMutableArray *trackPool;
@property (nonatomic, readwrite, retain) NSTimer *roundTimer;

// Calculated Properties
@property (nonatomic, readonly) NSTimeInterval roundTimeRemaining;
@property (nonatomic, readonly) NSTimeInterval gameTimeRemaining;
@property (nonatomic, readonly) NSUInteger currentRoundScore;
@property (nonatomic, readonly) BOOL hideCountdown;

- (IBAction)guessOne:(id)sender;
- (IBAction)guessTwo:(id)sender;
- (IBAction)guessThree:(id)sender;
- (IBAction)guessFour:(id)sender;

// Getting tracks 

-(void)waitAndFillTrackPool;
-(NSArray *)playlistsInFolder:(SPPlaylistFolder *)aFolder;
-(NSArray *)tracksFromPlaylistItems:(NSArray *)items;

// Getting tracks

-(SPTrack *)trackForUserToGuessWithAlternativeOne:(SPTrack **)alternative two:(SPTrack **)anotherAlternative three:(SPTrack **)aThirdAlternative;

// Game logic

-(void)guessTrack:(SPTrack *)itsTotallyThisOne;
-(void)roundTimeExpired;
-(void)startNewRound;
-(void)gameOverWithReason:(NSString *)reason;

-(void)startPlaybackOfTrack:(SPTrack *)aTrack;

@end
