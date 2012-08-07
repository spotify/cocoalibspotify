//
//  SPOfflineSyncTests.m
//  CocoaLibSpotify iOS Library
//
//  Created by Mauricio Hanika on 07.08.12.
//
//

#import "SPOfflineSyncTests.h"
#import "SPAsyncLoading.h"
#import "SPSession.h"
#import "SPPlaylist.h"
#import "SPPlaylistContainer.h"
#import "SPTrack.h"

@interface SPOfflineSyncTests()
@property (nonatomic, readwrite, strong) SPPlaylist *playlist;
@end

@implementation SPOfflineSyncTests

static NSString * const kTestPlaylistName = @"CocoaLibSpotify Test Playlist";
static NSString * const kTrackLoadingTestURI = @"spotify:track:5iIeIeH3LBSMK92cMIXrVD"; // Spotify Test Track

- (void)test1OfflineSyncOfPlaylist {
  SPSession *session = [SPSession sharedSession];
  
  [SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
    // Create test playlist
    SPPlaylistContainer *container = session.userPlaylists;
    SPTestAssert(container != nil, @"User playlists is nil");
    
		[SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
      
      SPTestAssert(notLoadedItems.count == 0, @"Playlist container loading timed out for %@", container);
      
      [container createPlaylistWithName:kTestPlaylistName callback:^(SPPlaylist *createdPlaylist) {
        SPTestAssert(createdPlaylist != nil, @"Created nil playlist");
        
        self.playlist = createdPlaylist;
        
        [SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
          SPTestAssert(notLoadedItems.count == 0, @"Playlist loading timed out for %@", createdPlaylist);
          
          NSURL *trackURL = [NSURL URLWithString:kTrackLoadingTestURI];
          [session trackForURL:trackURL callback:^(SPTrack *track) {
            SPTestAssert(track != nil, @"Track is nil");
            
            [SPAsyncLoading waitUntilLoaded:track timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
              SPTestAssert(notLoadedItems.count == 0, @"Track loading timed out for %@", track);
              
              __weak SPPlaylist *playlistWeakReference = createdPlaylist;
              [createdPlaylist addItem:track atIndex:0 callback:^(NSError *error) {
                SPTestAssert(error == nil, @"Error adding track: %@", error);
                
                [playlistWeakReference setMarkedForOfflinePlayback:YES];
                
                // Don't know how to do this in a more elegant way ...
                sleep(5);
                
                error = [session offlineSyncError];
                
                SPTestAssert(error == nil, @"Offline sync error: %@", error);
                SPPassTest();
              }];
            }];
          }];
        }];
      }];
    }];
  }];
}

- (void)test2Teardown {
  if (self.playlist != nil) {
    SPSession *session = [SPSession sharedSession];
    
    [SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
      SPTestAssert(notLoadedItems.count == 0, @"Session loading timeout: %@", session);
      
      SPPlaylistContainer *container = session.userPlaylists;
      SPTestAssert(container != nil, @"User playlists is nil");
      [SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
        
        SPTestAssert(notLoadedItems.count == 0, @"Playlist container loading timed out for %@", container);
        
        [container removeItem:self.playlist callback:^(NSError *error) {
          SPTestAssert(error == nil, @"Error removing playlist: %@", error);
          SPPassTest();
        }];
      }];
    }];
  }
}

@end
