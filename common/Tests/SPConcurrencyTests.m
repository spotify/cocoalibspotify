//
//  SPConcurrencyTests.m
//  CocoaLibSpotify iOS Library
//
//  Created by Daniel Kennett on 23/05/2012.
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

#import "SPConcurrencyTests.h"
#import "SPSession.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPImage.h"
#import "SPPlaylist.h"
#import "SPTrack.h"
#import "SPUser.h"
#import "TestConstants.h"

@implementation SPConcurrencyTests

-(void)testSessionPropertyCallbacks {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);

	// Ensure all block properties come back on the main queue
	SPSession *session = [SPSession sharedSession];

	[session fetchOfflineKeyTimeRemaining:^(NSTimeInterval remainingTime) {
		SPTestAssert([NSThread isMainThread], @"OfflineKeyTimeRemaining callback on wrong queue.");

    [session fetchLoginUserName:^(NSString *loginUserName) {
      SPTestAssert([NSThread isMainThread], @"FetchLoginUserName callback on wrong queue.");
      SPPassTest();
		}];
	}];
}

-(void)testInvalidGetterCallbacks {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	
	// Ensure all blocks come back on the main queue
	SPSession *session = [SPSession sharedSession];
	
	[session albumForURL:nil callback:^(SPAlbum *album) {
		SPTestAssert([NSThread isMainThread], @"albumForURL callback on wrong queue.");
		SPTestAssert(album == nil, @"Album callback with nil URL gave %@", album);
		
		[session artistForURL:nil callback:^(SPArtist *artist) {
			SPTestAssert([NSThread isMainThread], @"artistForURL callback on wrong queue.");
			SPTestAssert(artist == nil, @"Artist callback with nil URL gave %@", artist);
			
			[session imageForURL:nil callback:^(SPImage *image) {
				SPTestAssert([NSThread isMainThread], @"imageForURL callback on wrong queue.");
				SPTestAssert(image == nil, @"Image callback with nil URL gave %@", image);
				
				[session playlistForURL:nil callback:^(SPPlaylist *playlist) {
					SPTestAssert([NSThread isMainThread], @"playlistForURL callback on wrong queue.");
					SPTestAssert(playlist == nil, @"Playlist callback with nil URL gave %@", playlist);

					[session searchForURL:nil callback:^(SPSearch *search) {
						SPTestAssert([NSThread isMainThread], @"searchForURL callback on wrong queue.");
						SPTestAssert(search == nil, @"Search callback with nil URL gave %@", search);

						[session trackForURL:nil callback:^(SPTrack *track) {
							SPTestAssert([NSThread isMainThread], @"trackForURL callback on wrong queue.");
							SPTestAssert(track == nil, @"Track callback with nil URL gave %@", track);

							[session userForURL:nil callback:^(SPUser *user) {
								SPTestAssert([NSThread isMainThread], @"userForURL callback on wrong queue.");
								SPTestAssert(user == nil, @"User callback with nil URL gave %@", user);
								
								[session objectRepresentationForSpotifyURL:nil callback:^(sp_linktype linkType, id objectRepresentation) {
									SPTestAssert([NSThread isMainThread], @"objectRepresentationForSpotifyURL callback on wrong queue.");
									SPTestAssert(objectRepresentation == nil, @"Object representation callback with nil URL gave %@", objectRepresentation);
									SPTestAssert(linkType == SP_LINKTYPE_INVALID, @"Object representation callback with nil URL gave linktype of %lu", linkType);
									SPPassTest();
								}];							
							}];
						}];
					}];
				}];
			}];
		}];
	}];
}

-(void)testValidGetterCallbacks {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	
	// Ensure all blocks come back on the main queue
	SPSession *session = [SPSession sharedSession];
	
	[session albumForURL:[NSURL URLWithString:kAlbumLoadingTestURI] callback:^(SPAlbum *album) {
		SPTestAssert([NSThread isMainThread], @"albumForURL callback on wrong queue.");
		SPTestAssert(album != nil, @"Album callback with valid URL gave nil");
		
		[session artistForURL:[NSURL URLWithString:kArtistLoadingTestURI] callback:^(SPArtist *artist) {
			SPTestAssert([NSThread isMainThread], @"artistForURL callback on wrong queue.");
			SPTestAssert(artist != nil, @"Artist callback with valid URL gave nil");
			
			[session imageForURL:[NSURL URLWithString:kImageLoadingTestURI] callback:^(SPImage *image) {
				SPTestAssert([NSThread isMainThread], @"imageForURL callback on wrong queue.");
				SPTestAssert(image != nil, @"Image callback with valid URL gave nil");
				
				[session playlistForURL:[NSURL URLWithString:kPlaylistLoadingTestURI] callback:^(SPPlaylist *playlist) {
					SPTestAssert([NSThread isMainThread], @"playlistForURL callback on wrong queue.");
					SPTestAssert(playlist != nil, @"Playlist callback with valid URL gave nil");
					
					[session searchForURL:[NSURL URLWithString:kSearchLoadingTestURI] callback:^(SPSearch *search) {
						SPTestAssert([NSThread isMainThread], @"searchForURL callback on wrong queue.");
						SPTestAssert(search != nil, @"Search callback with valid URL gave nil");
						
						[session trackForURL:[NSURL URLWithString:kTrackLoadingTestURI] callback:^(SPTrack *track) {
							SPTestAssert([NSThread isMainThread], @"trackForURL callback on wrong queue.");
							SPTestAssert(track != nil, @"Track callback with valid URL gave nil");
							
							[session userForURL:[NSURL URLWithString:kUserLoadingTestURI] callback:^(SPUser *user) {
								SPTestAssert([NSThread isMainThread], @"userForURL callback on wrong queue.");
								SPTestAssert(user != nil, @"User callback with valid URL gave nil");
								
								[session objectRepresentationForSpotifyURL:[NSURL URLWithString:kTrackLoadingTestURI] callback:^(sp_linktype linkType, id objectRepresentation) {
									SPTestAssert([NSThread isMainThread], @"objectRepresentationForSpotifyURL callback on wrong queue.");
									SPTestAssert(objectRepresentation != nil, @"Object representation callback with valid URL gave nil");
									SPTestAssert(linkType != SP_LINKTYPE_INVALID, @"Object representation callback with valid URL gave linktype of %lu", linkType);
									SPPassTest();
								}];							
							}];
						}];
					}];
				}];
			}];
		}];
	}];
}

-(void)testInvalidConstructorCallbacks {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	
	// Ensure all blocks come back on the main queue
	SPSession *session = [SPSession sharedSession];
	
	[SPAlbum albumWithAlbumURL:nil inSession:session callback:^(SPAlbum *album) {
		SPTestAssert([NSThread isMainThread], @"albumWithAlbumURL callback on wrong queue.");
		SPTestAssert(album == nil, @"Album callback with nil URL gave %@", album);
		
		[SPArtist artistWithArtistURL:nil inSession:session callback:^(SPArtist *artist) {
			SPTestAssert([NSThread isMainThread], @"artistWithArtistURL callback on wrong queue.");
			SPTestAssert(artist == nil, @"Artist callback with nil URL gave %@", artist);
			
			[SPImage imageWithImageURL:nil inSession:session callback:^(SPImage *image) {
				SPTestAssert([NSThread isMainThread], @"imageWithImageURL callback on wrong queue.");
				SPTestAssert(image == nil, @"Image callback with nil URL gave %@", image);
				
				[SPPlaylist playlistWithPlaylistURL:nil inSession:session callback:^(SPPlaylist *playlist) {
					SPTestAssert([NSThread isMainThread], @"playlistWithPlaylistURL callback on wrong queue.");
					SPTestAssert(playlist == nil, @"Playlist callback with nil URL gave %@", playlist);
					
					[SPTrack trackForTrackURL:nil inSession:session callback:^(SPTrack *track) {
						SPTestAssert([NSThread isMainThread], @"trackForTrackURL callback on wrong queue.");
						SPTestAssert(track == nil, @"Track callback with nil URL gave %@", track);
						
						[SPUser userWithURL:nil inSession:session callback:^(SPUser *user) {
							SPTestAssert([NSThread isMainThread], @"userWithURL callback on wrong queue.");
							SPTestAssert(user == nil, @"User callback with nil URL gave %@", user);
							SPPassTest();
						}];
					}];
				}];
			}];
		}];
	}];
}

-(void)testValidConstructorCallbacks {

	SPAssertTestCompletesInTimeInterval(kDefaultNonAsyncLoadingTestTimeout);
	
	// Ensure all blocks come back on the main queue
	SPSession *session = [SPSession sharedSession];
	
	[SPAlbum albumWithAlbumURL:[NSURL URLWithString:kAlbumLoadingTestURI] inSession:session callback:^(SPAlbum *album) {
		SPTestAssert([NSThread isMainThread], @"albumForURL callback on wrong queue.");
		SPTestAssert(album != nil, @"Album callback with valid URL gave nil");
		
		[SPArtist artistWithArtistURL:[NSURL URLWithString:kArtistLoadingTestURI] inSession:session callback:^(SPArtist *artist) {
			SPTestAssert([NSThread isMainThread], @"artistForURL callback on wrong queue.");
			SPTestAssert(artist != nil, @"Artist callback with valid URL gave nil");
			
			[SPImage imageWithImageURL:[NSURL URLWithString:kImageLoadingTestURI] inSession:session callback:^(SPImage *image) {
				SPTestAssert([NSThread isMainThread], @"imageForURL callback on wrong queue.");
				SPTestAssert(image != nil, @"Image callback with valid URL gave nil");
				
				[SPPlaylist playlistWithPlaylistURL:[NSURL URLWithString:kPlaylistLoadingTestURI] inSession:session callback:^(SPPlaylist *playlist) {
					SPTestAssert([NSThread isMainThread], @"playlistForURL callback on wrong queue.");
					SPTestAssert(playlist != nil, @"Playlist callback with valid URL gave nil");
					
					[SPTrack trackForTrackURL:[NSURL URLWithString:kTrackLoadingTestURI] inSession:session callback:^(SPTrack *track) {
						SPTestAssert([NSThread isMainThread], @"trackForURL callback on wrong queue.");
						SPTestAssert(track != nil, @"Track callback with valid URL gave nil");
						
						[SPUser userWithURL:[NSURL URLWithString:kUserLoadingTestURI] inSession:session callback:^(SPUser *user) {
							SPTestAssert([NSThread isMainThread], @"userForURL callback on wrong queue.");
							SPTestAssert(user != nil, @"User callback with valid URL gave nil");
							SPPassTest();						
						}];
					}];
				}];
			}];
		}];
	}];
}

@end
