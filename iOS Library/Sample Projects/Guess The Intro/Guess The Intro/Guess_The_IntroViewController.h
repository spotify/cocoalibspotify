//
//  Guess_The_IntroViewController.h
//  Guess The Intro
//
//  Created by Daniel Kennett on 10/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CocoaLibSpotify.h"
#import "SPPlaybackManager.h"

@interface Guess_The_IntroViewController : UIViewController <SPSessionDelegate, SPPlaybackManagerDelegate> {
	UILabel *currentScoreLabel;
	UILabel *highScoreLabel;
	UIProgressView *roundProgressIndicator;
	UILabel *currentRoundScoreLabel;
	UIActivityIndicatorView *isLoadingView;
	UILabel *countdownLabel;
	UIButton *track1Button;
	UILabel *track1TitleLabel;
	UILabel *track2ArtistLabel;
	UIButton *track3Button;
	UILabel *track3TitleLabel;
	UILabel *track3ArtistLabel;
	UIButton *track4Button;
	UILabel *track4TitleLabel;
	UILabel *track4ArtistLabel;
	UILabel *track1ArtistLabel;
	UIButton *track2Button;
	UILabel *track2TitleLabel;
	UILabel *multiplierLabel;

	NSUInteger loginAttempts;
	NSNumberFormatter *formatter;
	
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

@property (nonatomic, readwrite, retain) SPPlaybackManager *playbackManager;

@property (nonatomic, readwrite, retain) SPPlaylist	*playlist;

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

@property (nonatomic, retain) IBOutlet UILabel *multiplierLabel;
@property (nonatomic, retain) IBOutlet UILabel *currentScoreLabel;
@property (nonatomic, retain) IBOutlet UILabel *highScoreLabel;
@property (nonatomic, retain) IBOutlet UIProgressView *roundProgressIndicator;
@property (nonatomic, retain) IBOutlet UILabel *currentRoundScoreLabel;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *isLoadingView;
@property (nonatomic, retain) IBOutlet UILabel *countdownLabel;

@property (nonatomic, retain) IBOutlet UIButton *track1Button;
@property (nonatomic, retain) IBOutlet UILabel *track1TitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *track1ArtistLabel;

@property (nonatomic, retain) IBOutlet UIButton *track2Button;
@property (nonatomic, retain) IBOutlet UILabel *track2TitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *track2ArtistLabel;

@property (nonatomic, retain) IBOutlet UIButton *track3Button;
@property (nonatomic, retain) IBOutlet UILabel *track3TitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *track3ArtistLabel;

@property (nonatomic, retain) IBOutlet UIButton *track4Button;
@property (nonatomic, retain) IBOutlet UILabel *track4TitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *track4ArtistLabel;



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
