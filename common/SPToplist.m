//
//  SPToplist.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 4/28/11.
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

#import "SPToplist.h"
#import "SPSession.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"
#import "SPArtist.h"
#import "SPAlbum.h"

@interface SPToplist ()

@property (nonatomic, readwrite, strong) NSArray *tracks;
@property (nonatomic, readwrite, strong) NSArray *artists;
@property (nonatomic, readwrite, strong) NSArray *albums;

@property (nonatomic, readwrite, copy) NSString *username;
@property (nonatomic, readwrite, strong) NSLocale *locale;
@property (nonatomic, readwrite, strong) SPSession *session;

@property (nonatomic, readwrite) BOOL tracksLoaded;
@property (nonatomic, readwrite) BOOL artistsLoaded;
@property (nonatomic, readwrite) BOOL albumsLoaded;

@property (nonatomic, readwrite) sp_toplistbrowse *albumBrowseOperation;
@property (nonatomic, readwrite) sp_toplistbrowse *artistBrowseOperation;
@property (nonatomic, readwrite) sp_toplistbrowse *trackBrowseOperation;

@property (nonatomic, readwrite, copy) NSError *loadError;

@end

void toplistbrowse_tracks_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_tracks_complete(sp_toplistbrowse *result, void *userdata) {
	
	@autoreleasepool {
	
		SPToplist *toplist = (__bridge_transfer SPToplist *)userdata;
		
		BOOL tracksAreLoaded = sp_toplistbrowse_is_loaded(result);
		sp_error errorCode = sp_toplistbrowse_error(result);
		NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
		NSArray *newTracks = nil;
		
		if (tracksAreLoaded) {
			
			int trackCount = sp_toplistbrowse_num_tracks(result);
			NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:trackCount];
			for (int currentTrack =  0; currentTrack < trackCount; currentTrack++) {
				sp_track *track = sp_toplistbrowse_track(result, currentTrack);
				if (track != NULL) {
					[tracks addObject:[SPTrack trackForTrackStruct:track inSession:toplist.session]];
				}
			}
			
			newTracks = [NSArray arrayWithArray:tracks];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			toplist.loadError = error;
			toplist.tracks = newTracks;
			toplist.tracksLoaded = tracksAreLoaded;
		});
	}
}

void toplistbrowse_artists_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_artists_complete(sp_toplistbrowse *result, void *userdata) {
	
	@autoreleasepool {
	
		SPToplist *toplist = (__bridge_transfer SPToplist *)userdata;
		
		BOOL artistsAreLoaded = sp_toplistbrowse_is_loaded(result);
		sp_error errorCode = sp_toplistbrowse_error(result);
		NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
		NSArray *newArtists = nil;
		
		if (artistsAreLoaded) {
			
			int artistCount = sp_toplistbrowse_num_artists(result);
			NSMutableArray *artists = [NSMutableArray arrayWithCapacity:artistCount];
			for (int currentArtist =  0; currentArtist < artistCount; currentArtist++) {
				sp_artist *artist = sp_toplistbrowse_artist(result, currentArtist);
				if (artist != NULL) {
					[artists addObject:[SPArtist artistWithArtistStruct:artist inSession:toplist.session]];
				}
			}
			
			newArtists = [NSArray arrayWithArray:artists];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			toplist.loadError = error;
			toplist.artists = newArtists;
			toplist.artistsLoaded = artistsAreLoaded;
		});
	}
}

void toplistbrowse_albums_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_albums_complete(sp_toplistbrowse *result, void *userdata) {
	
	@autoreleasepool {
	
		SPToplist *toplist = (__bridge_transfer SPToplist *)userdata;
		
		BOOL albumsAreLoaded = sp_toplistbrowse_is_loaded(result);
		sp_error errorCode = sp_toplistbrowse_error(result);
		NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
		NSArray *newAlbums = nil;
		
		if (albumsAreLoaded) {
			
			int albumCount = sp_toplistbrowse_num_albums(result);
			NSMutableArray *albums = [NSMutableArray arrayWithCapacity:albumCount];
			for (int currentAlbum =  0; currentAlbum < albumCount; currentAlbum++) {
				sp_album *album = sp_toplistbrowse_album(result, currentAlbum);
				if (album != NULL) {
					[albums addObject:[SPAlbum albumWithAlbumStruct:album inSession:toplist.session]];
				}
			}
			
			newAlbums = [NSArray arrayWithArray:albums];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			toplist.loadError = error;
			toplist.albums = newAlbums;
			toplist.albumsLoaded = albumsAreLoaded;
		});
	}
}

@implementation SPToplist

+(SPToplist *)globalToplistInSession:(SPSession *)aSession {
	return [[SPToplist alloc] initLocaleToplistWithLocale:nil 
												 inSession:aSession];
}

+(SPToplist *)toplistForLocale:(NSLocale *)toplistLocale inSession:(SPSession *)aSession {
	return [[SPToplist alloc] initLocaleToplistWithLocale:toplistLocale 
												 inSession:aSession];
}

+(SPToplist *)toplistForUserWithName:(NSString *)user inSession:(SPSession *)aSession {
	return [[SPToplist alloc] initUserToplistWithUsername:user
												 inSession:aSession];
}

+(SPToplist *)toplistForCurrentUserInSession:(SPSession *)aSession {
	return [[SPToplist alloc] initUserToplistWithUsername:nil
												 inSession:aSession];
}

-(id)initLocaleToplistWithLocale:(NSLocale *)toplistLocale inSession:(SPSession *)aSession {
	
	if (aSession != nil && (self = [super init])) {
		
		self.locale = toplistLocale;
		self.username = nil;
		self.session = aSession;
		
		dispatch_async([SPSession libSpotifyQueue], ^{
			
			sp_toplistregion region = SP_TOPLIST_REGION_EVERYWHERE;
			
			if (self.locale != nil) {
				NSString *countryCode = [self.locale objectForKey:NSLocaleCountryCode];
				if ([countryCode length] == 2) {
					const char *countryCodeChars = [countryCode UTF8String];
					region = SP_TOPLIST_REGION(countryCodeChars[0], countryCodeChars[1]);
				}
			}
			
			self.trackBrowseOperation = sp_toplistbrowse_create(aSession.session,
																SP_TOPLIST_TYPE_TRACKS,
																region, 
																NULL,
																&toplistbrowse_tracks_complete, 
																(__bridge_retained void *)(self));
			
			self.artistBrowseOperation = sp_toplistbrowse_create(aSession.session,
																 SP_TOPLIST_TYPE_ARTISTS,
																 region, 
																 NULL,
																 &toplistbrowse_artists_complete, 
																 (__bridge_retained void *)(self));
			
			self.albumBrowseOperation = sp_toplistbrowse_create(aSession.session,
																SP_TOPLIST_TYPE_ALBUMS,
																region, 
																NULL,
																&toplistbrowse_albums_complete, 
																(__bridge_retained void *)(self));
		});
		
		return self;
	}
	
	return nil;
	
}

-(id)initUserToplistWithUsername:(NSString *)user inSession:(SPSession *)aSession {

	if (aSession != nil && (self = [super init])) {
		
		self.locale = nil;
		self.username = user;
		self.session = aSession;
		
		dispatch_async([SPSession libSpotifyQueue], ^{
			
			sp_toplistregion region = SP_TOPLIST_REGION_USER;
			
			self.trackBrowseOperation = sp_toplistbrowse_create(aSession.session,
																SP_TOPLIST_TYPE_TRACKS,
																region, 
																[user UTF8String],
																&toplistbrowse_tracks_complete, 
																(__bridge_retained void *)(self));
			
			self.artistBrowseOperation = sp_toplistbrowse_create(aSession.session,
																 SP_TOPLIST_TYPE_ARTISTS,
																 region, 
																 [user UTF8String],
																 &toplistbrowse_artists_complete, 
																 (__bridge_retained void *)(self));
			
			self.albumBrowseOperation = sp_toplistbrowse_create(aSession.session,
																SP_TOPLIST_TYPE_ALBUMS,
																region, 
																[user UTF8String],
																&toplistbrowse_albums_complete, 
																(__bridge_retained void *)(self));
		});
		
		return self;
	}
	
	return nil;
}

-(NSString *)description {
	if (self.locale == nil)
		return [NSString stringWithFormat:@"%@: User toplist browse for %@", [super description], self.username];
	else
		return [NSString stringWithFormat:@"%@: Locale toplist browse for %@", [super description], self.locale];
}

@synthesize tracks;
@synthesize artists;
@synthesize albums;

@synthesize username;
@synthesize locale;
@synthesize session;

@synthesize tracksLoaded;
@synthesize albumsLoaded;
@synthesize artistsLoaded;
@synthesize loadError;

@synthesize albumBrowseOperation = _albumBrowseOperation;
@synthesize artistBrowseOperation = _artistBrowseOperation;
@synthesize trackBrowseOperation = _trackBrowseOperation;

-(sp_toplistbrowse *)albumBrowseOperation {
#if DEBUG
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
#endif
	return _albumBrowseOperation;
}

-(sp_toplistbrowse *)artistBrowseOperation {
#if DEBUG
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
#endif
	return _artistBrowseOperation;
}

-(sp_toplistbrowse *)trackBrowseOperation {
#if DEBUG
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
#endif
	return _trackBrowseOperation;
}

+(NSSet *)keyPathsForValuesAffectingLoaded {
	return [NSSet setWithObjects:@"tracksLoaded", @"albumsLoaded", @"artistsLoaded", nil];
}

-(BOOL)isLoaded {
	return self.tracksLoaded && self.artistsLoaded && self.albumsLoaded;
}

- (void)dealloc {
	
	sp_toplistbrowse *outgoing_artistbrowse = _artistBrowseOperation;
	_artistBrowseOperation = NULL;
	sp_toplistbrowse *outgoing_albumbrowse = _albumBrowseOperation;
	_albumBrowseOperation = NULL;
	sp_toplistbrowse *outgoing_trackbrowse = _trackBrowseOperation;
	_trackBrowseOperation = NULL;
	
	dispatch_async([SPSession libSpotifyQueue], ^() {
		if (outgoing_artistbrowse) sp_toplistbrowse_release(outgoing_artistbrowse);
		if (outgoing_albumbrowse) sp_toplistbrowse_release(outgoing_albumbrowse);
		if (outgoing_trackbrowse) sp_toplistbrowse_release(outgoing_trackbrowse);
	});
}

@end
