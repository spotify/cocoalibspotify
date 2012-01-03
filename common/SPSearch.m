//
//  SPSearch.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 4/21/11.
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

#import "SPSearch.h"
#import "SPSession.h"
#import "SPURLExtensions.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"

@interface SPSearch ()

@property (nonatomic, readwrite, retain) NSArray *tracks;
@property (nonatomic, readwrite, retain) NSArray *artists;
@property (nonatomic, readwrite, retain) NSArray *albums;

@property (nonatomic, readwrite) BOOL hasExhaustedTrackResults;
@property (nonatomic, readwrite) BOOL hasExhaustedArtistResults;
@property (nonatomic, readwrite) BOOL hasExhaustedAlbumResults;

@property (nonatomic, readwrite, copy) NSError *searchError;

@property (nonatomic, readwrite, copy) NSString *searchQuery;
@property (nonatomic, readwrite, copy) NSString *suggestedSearchQuery;

@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, retain) SPSession *session;
@property (nonatomic, readwrite) sp_search *activeSearch;

-(id)initWithSession:(SPSession *)aSession; // Designated initialiser.
-(void)searchDidComplete:(sp_search *)search wasSearchingForTracks:(BOOL)searchTracks artists:(BOOL)searchArtists albums:(BOOL)searchAlbums;

@end

static NSString * const kSPSearchCallbackSearchObjectKey = @"session";
static NSString * const kSPSearchCallbackSearchingTracksKey = @"tracks";
static NSString * const kSPSearchCallbackSearchingArtistsKey = @"artists";
static NSString * const kSPSearchCallbackSearchingAlbumsKey = @"albums";


#pragma mark C Callbacks

void search_complete(sp_search *result, void *userdata);
void search_complete(sp_search *result, void *userdata) {
	
	NSDictionary *properties = userdata;
	SPSearch *search = [properties valueForKey:kSPSearchCallbackSearchObjectKey];
	
	[search searchDidComplete:result 
		wasSearchingForTracks:[[properties valueForKey:kSPSearchCallbackSearchingTracksKey] boolValue]
					  artists:[[properties valueForKey:kSPSearchCallbackSearchingArtistsKey] boolValue]
					   albums:[[properties valueForKey:kSPSearchCallbackSearchingAlbumsKey] boolValue]];
	
	[properties release];
	// ^ Was retained when the search was created.
}

#pragma mark -

@implementation SPSearch

+(SPSearch *)searchWithURL:(NSURL *)searchURL inSession:(SPSession *)aSession {
	return [[[SPSearch alloc] initWithURL:searchURL inSession:aSession] autorelease];
}

+(SPSearch *)searchWithSearchQuery:(NSString *)searchQuery inSession:(SPSession *)aSession {
	return [[[SPSearch alloc] initWithSearchQuery:searchQuery inSession:aSession] autorelease];
}

-(id)initWithSession:(SPSession *)aSession {
	
	if ((self = [super init])) {
		self.session = aSession;
		self.tracks = [NSArray array];
		self.albums = [NSArray array];
		self.artists = [NSArray array];
	}
	return self;
}

-(id)initWithURL:(NSURL *)searchURL 
	   inSession:(SPSession *)aSession { 

	return [self initWithURL:searchURL
					pageSize:kSPSearchDefaultSearchPageSize
				   inSession:aSession];
}

-(id)initWithURL:(NSURL *)searchURL
		pageSize:(NSInteger)size
	   inSession:(SPSession *)aSession {
	
	if (searchURL != nil && [searchURL spotifyLinkType] == SP_LINKTYPE_SEARCH) {
		NSString *linkString = [searchURL absoluteString];
		return [self initWithSearchQuery:
				[NSURL urlDecodedStringForString:
				 [linkString stringByReplacingOccurrencesOfString:@"spotify:search:"
													   withString:@""]]
								pageSize:kSPSearchDefaultSearchPageSize
							   inSession:aSession];
	}
	[self release];
	return nil;
}

-(id)initWithSearchQuery:(NSString *)searchString
			   inSession:(SPSession *)aSession {
	
	return [self initWithSearchQuery:searchString
							pageSize:kSPSearchDefaultSearchPageSize 
						   inSession:aSession];
}

-(id)initWithSearchQuery:(NSString *)searchString
				pageSize:(NSInteger)size
			   inSession:(SPSession *)aSession {
	
	if ([searchString length] > 0 && size > 0 && aSession != nil) {
		
		if ((self = [self initWithSession:aSession])) {
			
			requestedAlbumResults = size;
			requestedArtistResults = size;
			requestedTrackResults = size;
			pageSize = size;
			self.searchQuery = searchString;
			
			[self addPageForArtists:YES albums:YES tracks:YES];
		}	
		return self;
		
	} else {
		[self release];
		return nil;
	}
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.searchQuery];
}

@synthesize tracks;
@synthesize artists;
@synthesize albums;

@synthesize hasExhaustedTrackResults;
@synthesize hasExhaustedArtistResults;
@synthesize hasExhaustedAlbumResults;

@synthesize searchError;

@synthesize searchQuery;
@synthesize suggestedSearchQuery;
@synthesize spotifyURL;
@synthesize session;

+(NSSet *)keyPathsForValuesAffectingSearchInProgress {
	return [NSSet setWithObject:@"activeSearch"];
}

-(BOOL)searchInProgress {
	return self.activeSearch != NULL && !sp_search_is_loaded(self.activeSearch);
}

-(sp_search *)activeSearch {
	return activeSearch;
}

-(void)setActiveSearch:(sp_search *)search {
	if (search != activeSearch) {
		if (activeSearch != NULL) {
			sp_search_release(activeSearch);
		}
		if (search != NULL) {
			sp_search_add_ref(search);
		}
		activeSearch = search;
	}
}

#pragma mark -

-(void)searchDidComplete:(sp_search *)search wasSearchingForTracks:(BOOL)searchTracks artists:(BOOL)searchArtists albums:(BOOL)searchAlbums {

	[self willChangeValueForKey:@"searchInProgress"];
	
	sp_error error = sp_search_error(search);
	
	if (error != SP_ERROR_OK) {
		self.searchError = [NSError spotifyErrorWithCode:error];
	}
	
	const char *suggestion = sp_search_did_you_mean(search);
	NSString *suggestionString = [NSString stringWithUTF8String:suggestion];
	
	if ([suggestionString length] > 0)
		self.suggestedSearchQuery = suggestionString;
		
	//Albums 
	
	if (searchAlbums) {
		
		int albumCount = sp_search_num_albums(search);
		
		if (albumCount > 0) {
			NSMutableArray *newAlbums = [NSMutableArray array];
			
			for (int currentAlbum = 0; currentAlbum < albumCount; currentAlbum++) {
				SPAlbum *album = [SPAlbum albumWithAlbumStruct:sp_search_album(search, currentAlbum)
													 inSession:self.session];
				if (album != nil) {
					[newAlbums addObject:album];
				}
			}
			albumCount = (int)[newAlbums count];
			self.albums = [self.albums arrayByAddingObjectsFromArray:newAlbums];
		}
		
		self.hasExhaustedAlbumResults = (albumCount < pageSize);
		requestedAlbumResults += albumCount;
	}
	
	//Artists
	
	if (searchArtists) {
		
		int artistCount = sp_search_num_artists(search);
		
		if (artistCount > 0) {
			NSMutableArray *newArtists = [NSMutableArray array];
			
			for (int currentArtist = 0; currentArtist < artistCount; currentArtist++) {
				SPArtist *artist = [SPArtist artistWithArtistStruct:sp_search_artist(search, currentArtist)];			
				if (artist != nil) {
					[newArtists addObject:artist];
				}
			}
			artistCount = (int)[newArtists count];
			self.artists = [self.artists arrayByAddingObjectsFromArray:newArtists];
		}
		
		self.hasExhaustedArtistResults = (artistCount < pageSize);
		requestedArtistResults += artistCount;
	}
	
	//Tracks 
	
	if (searchTracks) {
		
		int trackCount = sp_search_num_tracks(search);
		
		if (trackCount > 0) {
			NSMutableArray *newTracks = [NSMutableArray array];
			
			for (int currentTrack = 0; currentTrack < trackCount; currentTrack++) {
				SPTrack *track = [SPTrack trackForTrackStruct:sp_search_track(search, currentTrack)
													inSession:self.session];			
				if (track != nil) {
					[newTracks addObject:track];
				}
			}
			trackCount = (int)[newTracks count];
			self.tracks = [self.tracks arrayByAddingObjectsFromArray:newTracks];
		}
		
		self.hasExhaustedTrackResults = (trackCount < pageSize);
		requestedTrackResults += trackCount;
	}
	
	[self didChangeValueForKey:@"searchInProgress"];
}

#pragma mark -

-(BOOL)addTrackPage {
	return [self addPageForArtists:NO albums:NO tracks:YES];
}

-(BOOL)addArtistPage {
	return [self addPageForArtists:YES albums:NO tracks:NO];
}

-(BOOL)addAlbumPage {
	return [self addPageForArtists:NO albums:YES tracks:NO];
}

-(BOOL)addPageForArtists:(BOOL)searchArtist albums:(BOOL)searchAlbum tracks:(BOOL)searchTrack {
	
	if (!self.searchInProgress) {
		
		int trackOffset = 0, trackCount = 0, artistOffset = 0, artistCount = 0, albumOffset = 0, albumCount = 0;
		
		if (searchArtist && !self.hasExhaustedArtistResults) {
			artistOffset = (int)self.artists.count;
			artistCount = (int)pageSize;
		}
		
		if (searchAlbum && !self.hasExhaustedAlbumResults) {
			albumOffset = (int)self.albums.count;
			albumCount = (int)pageSize;
		}
		
		if (searchTrack && !self.hasExhaustedTrackResults) {
			trackOffset = (int)self.tracks.count;
			trackCount = (int)pageSize;
		}
		
		if (artistCount > 0 || albumCount > 0 || trackCount > 0) {
			
			NSMutableDictionary *userData = [[NSMutableDictionary alloc] initWithCapacity:4];
			// ^ Don't release userData, it needs to survive through a search operation. The complete callback releases it.
			
			[userData setValue:self forKey:kSPSearchCallbackSearchObjectKey];
			[userData setValue:[NSNumber numberWithBool:searchArtist] forKey:kSPSearchCallbackSearchingArtistsKey];
			[userData setValue:[NSNumber numberWithBool:searchAlbum] forKey:kSPSearchCallbackSearchingAlbumsKey];
			[userData setValue:[NSNumber numberWithBool:searchTrack] forKey:kSPSearchCallbackSearchingTracksKey];
			
			sp_search *newSearch = sp_search_create(self.session.session, 
													[self.searchQuery UTF8String], //query 
													trackOffset, // track_offset 
													trackCount, //track_count 
													albumOffset, //album_offset 
													albumCount, //album_count 
													artistOffset, //artist_offset 
													artistCount, //artist_count 
													&search_complete, //callback
													userData); // userdata
			if (newSearch != NULL) {
				self.activeSearch = newSearch;
				sp_search_release(newSearch);
				if (self.spotifyURL == nil) {
					sp_link *searchLink = sp_link_create_from_search(self.activeSearch);
					if (searchLink != NULL) {
						self.spotifyURL = [NSURL urlWithSpotifyLink:searchLink];
						sp_link_release(searchLink);
					}
				}
				return YES;
			} 
		} 
	}
	return NO;
}

#pragma mark -

- (void)dealloc {
	
	self.searchError = nil;
	self.tracks = nil;
	self.artists = nil;
	self.albums = nil;
	self.searchQuery = nil;
	self.suggestedSearchQuery = nil;
	self.session = nil;
	self.activeSearch = NULL;
	self.spotifyURL = nil;
	
	[super dealloc];
}

@end
