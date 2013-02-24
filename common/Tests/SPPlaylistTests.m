//
//  SPPlaylistTests.m
//  CocoaLibSpotify Mac Framework
//
//  Created by Daniel Kennett on 11/05/2012.
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

#import "SPPlaylistTests.h"
#import "SPSession.h"
#import "SPPlaylistContainer.h"
#import "SPPlaylist.h"
#import "SPPlaylistFolder.h"
#import "SPAsyncLoading.h"
#import "SPTrack.h"
#import "TestConstants.h"

@interface SPPlaylistTests ()
@property (nonatomic, readwrite, strong) SPPlaylist *playlist;
@end

@implementation SPPlaylistTests

@synthesize playlist;

-(void)test1InboxPlaylist {

	SPAssertTestCompletesInTimeInterval(kSPAsyncLoadingDefaultTimeout * 2);
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {
		
		SPTestAssert(session.inboxPlaylist != nil, @"Inbox playlist is nil");
		
		[SPAsyncLoading waitUntilLoaded:session.inboxPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
			
			SPTestAssert(notLoadedItems.count == 0, @"Playlist loading timed out for %@", session.inboxPlaylist);
			SPTestAssert(session.inboxPlaylist.items != nil, @"Inbox playlist's tracks is nil");
			SPPassTest();
		}];
	}];
}

-(void)test2StarredPlaylist {

	SPAssertTestCompletesInTimeInterval(kSPAsyncLoadingDefaultTimeout * 2);
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {
		
		SPTestAssert(session.starredPlaylist != nil, @"Starred playlist is nil");
		
		[SPAsyncLoading waitUntilLoaded:session.starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
			
			SPTestAssert(notLoadedItems.count == 0, @"Playlist loading timed out for %@", session.starredPlaylist);
			SPTestAssert(session.starredPlaylist.items != nil, @"Starred playlist's tracks is nil");
			SPPassTest();
		}];
	}];
}

-(void)test3PlaylistContainer {

	SPAssertTestCompletesInTimeInterval(kSPAsyncLoadingDefaultTimeout * 2);
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {
		
		SPPlaylistContainer *container = session.userPlaylists;
		SPTestAssert(container != nil, @"User playlists is nil");
		
		[SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
			
			SPTestAssert(notLoadedItems.count == 0, @"Playlist container loading timed out for %@", container);
			SPTestAssert(container.owner != nil, @"User playlists has nil owner");
			SPTestAssert(container.playlists != nil, @"User playlists has nil playlist tree");
			
			// Test below assumes user has > 0 playlists
			SPTestAssert(container.loaded == YES, @"userPlaylists not loaded");
			SPTestAssert(container.flattenedPlaylists.count > 0, @"No playlists loaded");

			SPPassTest();
		}];
	}];
}

-(void)test4PlaylistCreation {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout + (kSPAsyncLoadingDefaultTimeout * 3));
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {
		
		SPPlaylistContainer *container = session.userPlaylists;
		SPTestAssert(container != nil, @"User playlists is nil");
		
		[SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
			
			SPTestAssert(notLoadedItems.count == 0, @"Playlist container loading timed out for %@", container);
			
			[container createPlaylistWithName:kTestPlaylistName callback:^(SPPlaylist *createdPlaylist) {
				SPTestAssert(createdPlaylist != nil, @"Created nil playlist");
				SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"createPlaylistWithName callback on wrong queue.");
				
				self.playlist = createdPlaylist;
				
				[SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylist, NSArray *notLoadedPlaylist) {
					
					SPTestAssert(notLoadedPlaylist.count == 0, @"Playlist loading timed out for %@", createdPlaylist);
					SPTestAssert([container.flattenedPlaylists containsObject:createdPlaylist], @"Playlist container doesn't contain playlist %@", createdPlaylist);
					SPTestAssert([createdPlaylist.name isEqualToString:kTestPlaylistName], @"Created playlist has incorrect name: %@", createdPlaylist);
					SPPassTest();
				}];
			}];
		}];
	}];
}

-(void)test5PlaylistTrackManagement {
	
	__weak SPPlaylistTests *sself = self;

	SPAssertTestCompletesInTimeInterval((kDefaultNonAsyncLoadingTestTimeout * 2) + kSPAsyncLoadingDefaultTimeout);
	SPTestAssert(self.playlist != nil, @"Test playlist is nil - cannot run test");
	
	[SPAsyncLoading waitUntilLoaded:self.playlist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		
		SPTestAssert(notLoadedItems.count == 0, @"Playlist loading timed out for %@", self.playlist);
		
		[SPTrack trackForTrackURL:[NSURL URLWithString:kPlaylistTestTrack1TestURI] inSession:[SPSession sharedSession] callback:^(SPTrack *track1) {
			[SPTrack trackForTrackURL:[NSURL URLWithString:kPlaylistTestTrack2TestURI] inSession:[SPSession sharedSession] callback:^(SPTrack *track2) {
				
				SPTestAssert(track1 != nil, @"SPTrack returned nil for %@", kPlaylistTestTrack1TestURI);
				SPTestAssert(track2 != nil, @"SPTrack returned nil for %@", kPlaylistTestTrack2TestURI);
				
				[sself.playlist addItems:[NSArray arrayWithObjects:track1, track2, nil] atIndex:0 callback:^(NSError *error) {
					
					SPTestAssert(error == nil, @"Got error when adding to playlist: %@", error);
					SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"addItems callback on wrong queue.");
					
					// Tracks get converted to items.
					NSArray *originalPlaylistTracks = [self.playlist.items valueForKey:@"item"];
					SPTestAssert(originalPlaylistTracks.count == 2, @"Playlist doesn't have 2 tracks, instead has: %u", originalPlaylistTracks.count);
					SPTestAssert([originalPlaylistTracks objectAtIndex:0] == track1, @"Playlist track 0 should be %@, is actually %@", track1, [originalPlaylistTracks objectAtIndex:0]);
					SPTestAssert([originalPlaylistTracks objectAtIndex:1] == track2, @"Playlist track 1 should be %@, is actually %@", track2, [originalPlaylistTracks objectAtIndex:1]);
					
					[sself.playlist moveItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] toIndex:2 callback:^(NSError *moveError) {
						SPTestAssert(moveError == nil, @"Move operation returned error: %@", moveError);
						SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"moveItemsAtIndexes callback on wrong queue.");
						
						NSArray *movedPlaylistTracks = [self.playlist.items valueForKey:@"item"];
						SPTestAssert(movedPlaylistTracks.count == 2, @"Playlist doesn't have 2 tracks after move, instead has: %u", movedPlaylistTracks.count);
						SPTestAssert([movedPlaylistTracks objectAtIndex:0] == track2, @"Playlist track 0 should be %@ after move, is actually %@", track2, [movedPlaylistTracks objectAtIndex:0]);
						SPTestAssert([movedPlaylistTracks objectAtIndex:1] == track1, @"Playlist track 1 should be %@ after move, is actually %@", track1, [movedPlaylistTracks objectAtIndex:1]);
						                        
                        [sself.playlist removeItemAtIndex:0 callback:^(NSError *deletionError) {
							
                            SPTestAssert(![track1 isEqual:track2], @"Forcing track2 from being released");

							SPTestAssert(deletionError == nil, @"Removal operation returned error: %@", deletionError);
							SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"removeItemAtIndex		callback on wrong queue.");
							
							NSArray *afterDeletionPlaylistTracks = [self.playlist.items valueForKey:@"item"];
							SPTestAssert(afterDeletionPlaylistTracks.count == 1, @"Playlist doesn't have 1 tracks after track remove, instead has: %u", afterDeletionPlaylistTracks.count);
							SPTestAssert([afterDeletionPlaylistTracks objectAtIndex:0] == track1, @"Playlist track 0 should be %@ after track remove, is actually %@", track1, [afterDeletionPlaylistTracks objectAtIndex:0]);
                            
                            // Added this part to add another track to the playlist that will be used as a offline test
                            [sself.playlist addItems:[NSArray arrayWithObjects:track2, nil] atIndex:0 callback:^(NSError *error) {
                                
                                SPTestAssert(error == nil, @"Got error when adding to playlist: %@", error);
                                SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"addItems callback on wrong queue.");
                                
                                // Tracks get converted to items.
                                NSArray *originalPlaylistTracks = [self.playlist.items valueForKey:@"item"];
                                SPTestAssert(originalPlaylistTracks.count == 2, @"Playlist doesn't have 2 tracks, instead has: %u", originalPlaylistTracks.count);
                            }];
                            SPPassTest();
                        }];
					}];
				}];
			}];
		}];
	}];
}

-(void)test6PlaylistOffline {
	SPTestAssert(self.playlist != nil, @"Test playlist is nil - cannot mark offline");
	
    __block SPPlaylistTests *sself = self;

	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {

		[sself.playlist addObserver:self forKeyPath:@"offlineStatus" options:0 context:nil];
		[sself.playlist addObserver:self forKeyPath:@"offlineDownloadProgress" options:0 context:nil];
        
        sself.playlist.markedForOfflinePlayback = YES;

	}];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    static int state = 0;

    if ([keyPath isEqualToString:@"offlineStatus"]) {
        switch (playlist.offlineStatus) {
            case SP_PLAYLIST_OFFLINE_STATUS_NO:
                NSLog(@"SP_PLAYLIST_OFFLINE_STATUS_NO");
                state = -1;
                break;
                
            case SP_PLAYLIST_OFFLINE_STATUS_YES:
                if (state == 2) {
                    state = 3;
                    SPPassTest(); // have passed state downloading, lets call it OK
                } else if (state == 3) {
                    // don't fail now
                } else {
                    state = -1;
                }
                NSLog(@"SP_PLAYLIST_OFFLINE_STATUS_YES");
                break;
                
            case SP_PLAYLIST_OFFLINE_STATUS_DOWNLOADING:
                if (state == 1 || state == 2)
                    state = 2;
                else
                    state = -1;
                NSLog(@"SP_PLAYLIST_OFFLINE_STATUS_DOWNLOADING");
                break;
                
            case SP_PLAYLIST_OFFLINE_STATUS_WAITING:
                if (state == 0 || state == 1)
                    state = 1;
                else
                    state = -1;
                NSLog(@"SP_PLAYLIST_OFFLINE_STATUS_WAITING");
                break;
        }
        SPTestAssert(state != -1, @"Failed sync playlist for offline");
    }
    if ([keyPath isEqualToString:@"offlineDownloadProgress"]) {
        [SPSession dispatchToLibSpotifyThread:^{
            sp_offline_sync_status status = {0};
            sp_offline_sync_get_status([SPSession sharedSession].session, &status);
            NSLog(@"syncing %d %d", status.syncing, [SPSession sharedSession].offlineSyncing);
        }];
        NSLog(@"%d %f", self.playlist.items.count, self.playlist.offlineDownloadProgress);
    }
}

-(void)cleanupTest6 {
    [self.playlist removeObserver:self forKeyPath:@"offlineStatus" context:nil];
    [self.playlist removeObserver:self forKeyPath:@"offlineDownloadProgress" context:nil];
}

-(void)test7PlaylistDeletion {
	[self cleanupTest6];
    
	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout + (kSPAsyncLoadingDefaultTimeout * 2));
	SPTestAssert(self.playlist != nil, @"Test playlist is nil - cannot remove");
	
	// Removing playlist
	SPSession *session = [SPSession sharedSession];
	
	[SPAsyncLoading waitUntilLoaded:session timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {
		
		SPPlaylistContainer *container = session.userPlaylists;
		SPTestAssert(container != nil, @"User playlists is nil");
		
		[SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
			
			SPTestAssert(notLoadedItems.count == 0, @"Playlist container loading timed out for %@", container);
			
			[container removeItem:self.playlist callback:^(NSError *error) {
				
				SPTestAssert(error == nil, @"Removal operation returned error: %@", error);
				SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"removeItem callback on wrong queue.");
				SPTestAssert(![container.flattenedPlaylists containsObject:self.playlist], @"Playlist container still contains playlist: %@", self.playlist);
				self.playlist = nil;
				SPPassTest();
			}];
		}];
	}];
}

@end
