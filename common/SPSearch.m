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
#import "SPPlaylist.h"

@interface SPSearch ()

@property (nonatomic, readwrite, strong) NSArray *tracks;
@property (nonatomic, readwrite, strong) NSArray *artists;
@property (nonatomic, readwrite, strong) NSArray *albums;
@property (nonatomic, readwrite, strong) NSArray *playlists;

@property (nonatomic, readwrite) BOOL hasExhaustedTrackResults;
@property (nonatomic, readwrite) BOOL hasExhaustedArtistResults;
@property (nonatomic, readwrite) BOOL hasExhaustedAlbumResults;
@property (nonatomic, readwrite) BOOL hasExhaustedPlaylistResults;

@property (nonatomic, readwrite, copy) NSError *searchError;
@property (nonatomic, readwrite) sp_search_type searchType;

@property (nonatomic, readwrite, copy) NSString *searchQuery;
@property (nonatomic, readwrite, copy) NSString *suggestedSearchQuery;

@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, strong) SPSession *session;
@property (nonatomic, readwrite) sp_search *activeSearch;

@property (nonatomic, readwrite, getter = isLoaded) BOOL loaded;

-(id)initWithSession:(SPSession *)aSession; // Designated initialiser.
-(void)searchDidComplete:(sp_search *)search wasSearchingForTracks:(BOOL)searchTracks artists:(BOOL)searchArtists albums:(BOOL)searchAlbums playlists:(BOOL)searchPlaylists;

@end

static NSString * const kSPSearchCallbackSearchObjectKey = @"session";
static NSString * const kSPSearchCallbackSearchingTracksKey = @"tracks";
static NSString * const kSPSearchCallbackSearchingArtistsKey = @"artists";
static NSString * const kSPSearchCallbackSearchingAlbumsKey = @"albums";
static NSString * const kSPSearchCallbackSearchingPlaylistsKey = @"playlists";


#pragma mark C Callbacks

void search_complete(sp_search *result, void *userdata);
void search_complete(sp_search *result, void *userdata) {
	
	NSDictionary *properties = (__bridge_transfer NSDictionary *)userdata;
	// ^ __bridge_transfer the userData dictionary so it's released correctly.
	SPSearch *search = [properties valueForKey:kSPSearchCallbackSearchObjectKey];
	
	[search searchDidComplete:result 
		wasSearchingForTracks:[[properties valueForKey:kSPSearchCallbackSearchingTracksKey] boolValue]
					  artists:[[properties valueForKey:kSPSearchCallbackSearchingArtistsKey] boolValue]
					   albums:[[properties valueForKey:kSPSearchCallbackSearchingAlbumsKey] boolValue]
					playlists:[[properties valueForKey:kSPSearchCallbackSearchingPlaylistsKey] boolValue]];
}

#pragma mark -

@implementation SPSearch {
	sp_search *_activeSearch;
	NSInteger requestedTrackResults;
	NSInteger requestedArtistResults;
	NSInteger requestedAlbumResults;
	NSInteger requestedPlaylistResults;
	NSInteger pageSize;
}

+(SPSearch *)searchWithURL:(NSURL *)searchURL inSession:(SPSession *)aSession {
	return [[SPSearch alloc] initWithURL:searchURL inSession:aSession];
}

+(SPSearch *)searchWithSearchQuery:(NSString *)searchQuery inSession:(SPSession *)aSession {
	return [[SPSearch alloc] initWithSearchQuery:searchQuery inSession:aSession];
}

+(SPSearch *)liveSearchWithSearchQuery:(NSString *)searchQuery inSession:(SPSession *)aSession {
	return [[SPSearch alloc] initWithSearchQuery:searchQuery inSession:aSession type:SP_SEARCH_SUGGEST];
}

-(id)initWithSession:(SPSession *)aSession {
	
	if ((self = [super init])) {
		self.session = aSession;
		self.tracks = [NSArray array];
		self.albums = [NSArray array];
		self.artists = [NSArray array];
		self.playlists = [NSArray array];
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
								pageSize:size
							   inSession:aSession
									type:SP_SEARCH_STANDARD];
	}
	return nil;
}

-(id)initWithSearchQuery:(NSString *)searchString
			   inSession:(SPSession *)aSession {
	
	return [self initWithSearchQuery:searchString
							pageSize:kSPSearchDefaultSearchPageSize 
						   inSession:aSession
								type:SP_SEARCH_STANDARD];
}

-(id)initWithSearchQuery:(NSString *)searchString
			   inSession:(SPSession *)aSession
					type:(sp_search_type)type {
	
	return [self initWithSearchQuery:searchString
							pageSize:kSPSearchDefaultSearchPageSize
						   inSession:aSession
								type:type];
	
}

-(id)initWithSearchQuery:(NSString *)searchString
				pageSize:(NSInteger)size
			   inSession:(SPSession *)aSession {
	
	return [self initWithSearchQuery:searchString
							pageSize:size
						   inSession:aSession
								type:SP_SEARCH_STANDARD];
}

-(id)initWithSearchQuery:(NSString *)searchString
				pageSize:(NSInteger)size
			   inSession:(SPSession *)aSession
					type:(sp_search_type)type {
	
	if ([searchString length] > 0 && size > 0 && aSession != nil) {
		
		if ((self = [self initWithSession:aSession])) {
			
			requestedAlbumResults = size;
			requestedArtistResults = size;
			requestedTrackResults = size;
			pageSize = size;
			self.searchQuery = searchString;
			self.searchType = type;
			
			[self addPageForArtists:YES albums:YES tracks:YES playlists:YES];
		}	
		return self;
		
	} else {
		return nil;
	}
	
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.searchQuery];
}

@synthesize tracks;
@synthesize artists;
@synthesize albums;
@synthesize playlists;

@synthesize hasExhaustedTrackResults;
@synthesize hasExhaustedArtistResults;
@synthesize hasExhaustedAlbumResults;
@synthesize hasExhaustedPlaylistResults;

@synthesize searchType;
@synthesize searchError;
@synthesize loaded;

@synthesize searchQuery;
@synthesize suggestedSearchQuery;
@synthesize spotifyURL;
@synthesize session;

-(sp_search *)activeSearch {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif
	return _activeSearch;
}

-(void)setActiveSearch:(sp_search *)search {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif
	if (search != _activeSearch) {
		if (_activeSearch != NULL) {
			sp_search_release(_activeSearch);
		}
		if (search != NULL) {
			sp_search_add_ref(search);
		}
		_activeSearch = search;
	}
}

#pragma mark -

-(void)searchDidComplete:(sp_search *)search wasSearchingForTracks:(BOOL)searchTracks artists:(BOOL)searchArtists albums:(BOOL)searchAlbums playlists:(BOOL)searchPlaylists {
	
	SPAssertOnLibSpotifyThread();
	
	sp_error errorCode = sp_search_error(search);
	NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
	NSString *newSuggestion = nil;
	NSArray *additionalAlbums = nil;
	BOOL newHasExhaustedAlbums = NO;
	
	NSArray *additionalArtists = nil;
	BOOL newHasExhaustedArtists = NO;
	
	NSArray *additionalTracks = nil;
	BOOL newHasExhaustedTracks = NO;
	
	NSArray *additionalPlaylists = nil;
	BOOL newHasExhaustedPlaylists = NO;
	
	const char *suggestion = sp_search_did_you_mean(search);
	NSString *suggestionString = [NSString stringWithUTF8String:suggestion];
	
	if ([suggestionString length] > 0)
		newSuggestion = suggestionString;
	
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
			additionalAlbums = newAlbums;
		}
		
		newHasExhaustedAlbums = (albumCount < pageSize);
	}
	
	//Artists
	
	if (searchArtists) {
		
		int artistCount = sp_search_num_artists(search);
		
		if (artistCount > 0) {
			NSMutableArray *newArtists = [NSMutableArray array];
			
			for (int currentArtist = 0; currentArtist < artistCount; currentArtist++) {
				SPArtist *artist = [SPArtist artistWithArtistStruct:sp_search_artist(search, currentArtist) inSession:self.session];			
				if (artist != nil) {
					[newArtists addObject:artist];
				}
			}
			artistCount = (int)[newArtists count];
			additionalArtists = newArtists;
		}
		newHasExhaustedArtists = (artistCount < pageSize);
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
			additionalTracks = newTracks;
		}
		
		newHasExhaustedTracks = (trackCount < pageSize);
	}
	
	if (searchPlaylists) {
		
		int playlistCount = sp_search_num_playlists(search);
		
		if (playlistCount > 0) {
			NSMutableArray *newPlaylists = [NSMutableArray array];
			
			for (int currentPlaylist = 0; currentPlaylist < playlistCount; currentPlaylist++) {
				const char *playlistLinkStr = sp_search_playlist_uri(search, currentPlaylist);
				sp_link *playlistLink = sp_link_create_from_string(playlistLinkStr);
				sp_playlist *pl = sp_playlist_create(self.session.session, playlistLink);
				
				SPPlaylist *playlist = [SPPlaylist playlistWithPlaylistStruct:pl inSession:self.session];
				
				sp_playlist_release(pl);
				sp_link_release(playlistLink);
				
				if (playlist != nil) {
					[newPlaylists addObject:playlist];
				}
			}
			playlistCount = (int)[newPlaylists count];
			additionalPlaylists = newPlaylists;
		}
		
		newHasExhaustedPlaylists = (playlistCount < pageSize);
	}
	
	self.activeSearch = NULL;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		self.searchError = error;
		self.suggestedSearchQuery = newSuggestion;
		self.albums = [self.albums arrayByAddingObjectsFromArray:additionalAlbums];
		self.hasExhaustedAlbumResults = newHasExhaustedAlbums;
		requestedAlbumResults += additionalAlbums.count;
		
		self.artists = [self.artists arrayByAddingObjectsFromArray:additionalArtists];
		self.hasExhaustedArtistResults = newHasExhaustedArtists;
		requestedArtistResults += additionalArtists.count;
		
		self.tracks	= [self.tracks arrayByAddingObjectsFromArray:additionalTracks];
		self.hasExhaustedTrackResults = newHasExhaustedTracks;
		requestedTrackResults += additionalTracks.count;
		
		self.playlists = [self.playlists arrayByAddingObjectsFromArray:additionalPlaylists];
		self.hasExhaustedPlaylistResults = newHasExhaustedPlaylists;
		requestedPlaylistResults += additionalPlaylists.count;
		
		self.loaded = YES;
		
	});
}

#pragma mark -

-(BOOL)addTrackPage {
	return [self addPageForArtists:NO albums:NO tracks:YES playlists:NO];
}

-(BOOL)addArtistPage {
	return [self addPageForArtists:YES albums:NO tracks:NO playlists:NO];
}

-(BOOL)addAlbumPage {
	return [self addPageForArtists:NO albums:YES tracks:NO playlists:NO];
}

-(BOOL)addPlaylistPage {
	return [self addPageForArtists:NO albums:NO tracks:NO playlists:YES];
}

-(BOOL)addPageForArtists:(BOOL)searchArtist albums:(BOOL)searchAlbum tracks:(BOOL)searchTrack playlists:(BOOL)searchPlaylist {
	
	int trackOffset = 0, trackCount = 0, artistOffset = 0, artistCount = 0, albumOffset = 0, albumCount = 0, playlistOffset = 0, playlistCount = 0;
	
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
	
	if (searchPlaylist && !self.hasExhaustedPlaylistResults) {
		playlistOffset = (int)self.playlists.count;
		playlistCount = (int)pageSize;
	}
	
	if (artistCount == 0 && albumCount == 0 && trackCount == 0 && playlistCount == 0)
		return NO;
	
	dispatch_libspotify_async(^{
		
		NSMutableDictionary *userData = [[NSMutableDictionary alloc] initWithCapacity:5];
		
		[userData setValue:self forKey:kSPSearchCallbackSearchObjectKey];
		[userData setValue:[NSNumber numberWithBool:searchArtist] forKey:kSPSearchCallbackSearchingArtistsKey];
		[userData setValue:[NSNumber numberWithBool:searchAlbum] forKey:kSPSearchCallbackSearchingAlbumsKey];
		[userData setValue:[NSNumber numberWithBool:searchTrack] forKey:kSPSearchCallbackSearchingTracksKey];
		[userData setValue:[NSNumber numberWithBool:searchPlaylist] forKey:kSPSearchCallbackSearchingPlaylistsKey];
		
		sp_search *newSearch = sp_search_create(self.session.session, 
												[self.searchQuery UTF8String], //query 
												trackOffset, // track_offset 
												trackCount, //track_count 
												albumOffset, //album_offset 
												albumCount, //album_count 
												artistOffset, //artist_offset 
												artistCount, //artist_count 
												playlistOffset, // playlist_offset,
												playlistCount, // playlist_count
												self.searchType,
												&search_complete, //callback
												(__bridge_retained void *)userData); // userdata
		// ^ __bridge_retain the userData dictionary, it needs to survive through a search operation. The complete callback releases it.
		
		if (newSearch == NULL)
			return;
		
		self.activeSearch = newSearch;
		sp_search_release(newSearch);
		
		if (self.spotifyURL == nil) {
			sp_link *searchLink = sp_link_create_from_search(self.activeSearch);
			if (searchLink != NULL) {
				NSURL *url = [NSURL urlWithSpotifyLink:searchLink];
				dispatch_async(dispatch_get_main_queue(), ^() { self.spotifyURL = url; });
				sp_link_release(searchLink);
			}
		}
	});
	
	self.loaded = NO;
	return YES;
	
}

#pragma mark -

-(void)dealloc {
	sp_search *outgoing_search = _activeSearch;
	_activeSearch = NULL;
	dispatch_libspotify_async(^() { if (outgoing_search) sp_search_release(outgoing_search); });
}

@end
