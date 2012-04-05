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

@interface Guess_The_IntroViewController : UIViewController <SPSessionDelegate, SPPlaybackManagerDelegate, SPLoginViewControllerDelegate> {
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

@property (nonatomic, readwrite, strong) SPPlaybackManager *playbackManager;

@property (nonatomic, readwrite, strong) SPPlaylist	*playlist;

@property (nonatomic, strong, readwrite) SPToplist *regionTopList;
@property (nonatomic, strong, readwrite) SPToplist *userTopList;

@property (nonatomic, strong, readwrite) SPTrack *firstSuggestion;
@property (nonatomic, strong, readwrite) SPTrack *secondSuggestion;
@property (nonatomic, strong, readwrite) SPTrack *thirdSuggestion;
@property (nonatomic, strong, readwrite) SPTrack *fourthSuggestion;

@property (nonatomic, readwrite) BOOL canPushOne;
@property (nonatomic, readwrite) BOOL canPushTwo;
@property (nonatomic, readwrite) BOOL canPushThree;
@property (nonatomic, readwrite) BOOL canPushFour;

@property (nonatomic, readwrite) NSUInteger multiplier;
@property (nonatomic, readwrite) NSUInteger score;
@property (nonatomic, readwrite, copy) NSDate *roundStartDate;
@property (nonatomic, readwrite, copy) NSDate *gameStartDate;
@property (nonatomic, readwrite, strong) NSMutableArray *trackPool;
@property (nonatomic, readwrite, strong) NSTimer *roundTimer;

@property (nonatomic, strong) IBOutlet UILabel *multiplierLabel;
@property (nonatomic, strong) IBOutlet UILabel *currentScoreLabel;
@property (nonatomic, strong) IBOutlet UILabel *highScoreLabel;
@property (nonatomic, strong) IBOutlet UIProgressView *roundProgressIndicator;
@property (nonatomic, strong) IBOutlet UILabel *currentRoundScoreLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *isLoadingView;
@property (nonatomic, strong) IBOutlet UILabel *countdownLabel;

@property (nonatomic, strong) IBOutlet UIButton *track1Button;
@property (nonatomic, strong) IBOutlet UILabel *track1TitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *track1ArtistLabel;

@property (nonatomic, strong) IBOutlet UIButton *track2Button;
@property (nonatomic, strong) IBOutlet UILabel *track2TitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *track2ArtistLabel;

@property (nonatomic, strong) IBOutlet UIButton *track3Button;
@property (nonatomic, strong) IBOutlet UILabel *track3TitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *track3ArtistLabel;

@property (nonatomic, strong) IBOutlet UIButton *track4Button;
@property (nonatomic, strong) IBOutlet UILabel *track4TitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *track4ArtistLabel;



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
