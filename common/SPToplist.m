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

@property (nonatomic, readwrite, retain) NSArray *tracks;
@property (nonatomic, readwrite, retain) NSArray *artists;
@property (nonatomic, readwrite, retain) NSArray *albums;

@property (nonatomic, readwrite, copy) NSString *username;
@property (nonatomic, readwrite, retain) NSLocale *locale;
@property (nonatomic, readwrite, retain) SPSession *session;

@property (nonatomic, readwrite) BOOL tracksLoaded;
@property (nonatomic, readwrite) BOOL artistsLoaded;
@property (nonatomic, readwrite) BOOL albumsLoaded;

@property (nonatomic, readwrite, copy) NSError *loadError;

@end

void toplistbrowse_tracks_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_tracks_complete(sp_toplistbrowse *result, void *userdata) {
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	SPToplist *toplist = userdata;
	
	toplist.tracksLoaded = sp_toplistbrowse_is_loaded(result);
	sp_error errorCode = sp_toplistbrowse_error(result);
	
	if (errorCode != SP_ERROR_OK) {
		toplist.loadError = [NSError spotifyErrorWithCode:errorCode];
	} else {
		toplist.loadError = nil;
	}
	
	if (toplist.tracksLoaded) {
		
		int trackCount = sp_toplistbrowse_num_tracks(result);
		NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:trackCount];
		for (int currentTrack =  0; currentTrack < trackCount; currentTrack++) {
			sp_track *track = sp_toplistbrowse_track(result, currentTrack);
			if (track != NULL) {
				[tracks addObject:[SPTrack trackForTrackStruct:track inSession:toplist.session]];
			}
		}
		
		toplist.tracks = [NSArray arrayWithArray:tracks];
	}
	
	[pool drain];
}

void toplistbrowse_artists_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_artists_complete(sp_toplistbrowse *result, void *userdata) {
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	SPToplist *toplist = userdata;
	
	toplist.artistsLoaded = sp_toplistbrowse_is_loaded(result);
	sp_error errorCode = sp_toplistbrowse_error(result);
	
	if (errorCode != SP_ERROR_OK) {
		toplist.loadError = [NSError spotifyErrorWithCode:errorCode];
	} else {
		toplist.loadError = nil;
	}
	
	if (toplist.artistsLoaded) {
		
		int artistCount = sp_toplistbrowse_num_artists(result);
		NSMutableArray *artists = [NSMutableArray arrayWithCapacity:artistCount];
		for (int currentArtist =  0; currentArtist < artistCount; currentArtist++) {
			sp_artist *artist = sp_toplistbrowse_artist(result, currentArtist);
			if (artist != NULL) {
				[artists addObject:[SPArtist artistWithArtistStruct:artist]];
			}
		}
		
		toplist.artists = [NSArray arrayWithArray:artists];
	}
	
	[pool drain];
}

void toplistbrowse_albums_complete(sp_toplistbrowse *result, void *userdata);
void toplistbrowse_albums_complete(sp_toplistbrowse *result, void *userdata) {
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	SPToplist *toplist = userdata;
	
	toplist.albumsLoaded = sp_toplistbrowse_is_loaded(result);
	sp_error errorCode = sp_toplistbrowse_error(result);
	
	if (errorCode != SP_ERROR_OK) {
		toplist.loadError = [NSError spotifyErrorWithCode:errorCode];
	} else {
		toplist.loadError = nil;
	}
	
	if (toplist.albumsLoaded) {
		
		int albumCount = sp_toplistbrowse_num_albums(result);
		NSMutableArray *albums = [NSMutableArray arrayWithCapacity:albumCount];
		for (int currentAlbum =  0; currentAlbum < albumCount; currentAlbum++) {
			sp_album *album = sp_toplistbrowse_album(result, currentAlbum);
			if (album != NULL) {
				[albums addObject:[SPAlbum albumWithAlbumStruct:album inSession:toplist.session]];
			}
		}
		
		toplist.albums = [NSArray arrayWithArray:albums];
	}
	
	[pool drain];
}

@implementation SPToplist

+(SPToplist *)globalToplistInSession:(SPSession *)aSession {
	return [[[SPToplist alloc] initLocaleToplistWithLocale:nil 
												 inSession:aSession] autorelease];
}

+(SPToplist *)toplistForLocale:(NSLocale *)toplistLocale inSession:(SPSession *)aSession {
	return [[[SPToplist alloc] initLocaleToplistWithLocale:toplistLocale 
												 inSession:aSession] autorelease];
}

+(SPToplist *)toplistForUserWithName:(NSString *)user inSession:(SPSession *)aSession {
	return [[[SPToplist alloc] initUserToplistWithUsername:user
												 inSession:aSession] autorelease];
}

+(SPToplist *)toplistForCurrentUserInSession:(SPSession *)aSession {
	return [[[SPToplist alloc] initUserToplistWithUsername:nil
												 inSession:aSession] autorelease];
}

-(id)initLocaleToplistWithLocale:(NSLocale *)toplistLocale inSession:(SPSession *)aSession {
	
	if (aSession != nil && (self = [super init])) {
		
		self.locale = toplistLocale;
		self.username = nil;
		self.session = aSession;
		
		sp_toplistregion region = SP_TOPLIST_REGION_EVERYWHERE;
	
		if (self.locale != nil) {
			NSString *countryCode = [self.locale objectForKey:NSLocaleCountryCode];
			if ([countryCode length] == 2) {
				const char *countryCodeChars = [countryCode UTF8String];
				region = SP_TOPLIST_REGION(countryCodeChars[0], countryCodeChars[1]);
			}
		}
		
		trackBrowseOperation = sp_toplistbrowse_create(self.session.session,
													   SP_TOPLIST_TYPE_TRACKS,
													   region, 
													   NULL,
													   &toplistbrowse_tracks_complete, 
													   self);
		
		artistBrowseOperation = sp_toplistbrowse_create(self.session.session,
													   SP_TOPLIST_TYPE_ARTISTS,
													   region, 
													   NULL,
													   &toplistbrowse_artists_complete, 
													   self);
		
		albumBrowseOperation = sp_toplistbrowse_create(self.session.session,
													   SP_TOPLIST_TYPE_ALBUMS,
													   region, 
													   NULL,
													   &toplistbrowse_albums_complete, 
													   self);
		return self;
	}
	
	[self release];
	return nil;
	
}

-(id)initUserToplistWithUsername:(NSString *)user inSession:(SPSession *)aSession {

	if (aSession != nil && (self = [super init])) {
		
		self.locale = nil;
		self.username = user;
		self.session = aSession;
		sp_toplistregion region = SP_TOPLIST_REGION_USER;
		
		trackBrowseOperation = sp_toplistbrowse_create(self.session.session,
													   SP_TOPLIST_TYPE_TRACKS,
													   region, 
													   [self.username UTF8String],
													   &toplistbrowse_tracks_complete, 
													   self);
		
		artistBrowseOperation = sp_toplistbrowse_create(self.session.session,
														SP_TOPLIST_TYPE_ARTISTS,
														region, 
														[self.username UTF8String],
														&toplistbrowse_artists_complete, 
														self);
		
		albumBrowseOperation = sp_toplistbrowse_create(self.session.session,
													   SP_TOPLIST_TYPE_ALBUMS,
													   region, 
													   [self.username UTF8String],
													   &toplistbrowse_albums_complete, 
													   self);
		
		return self;
	}
	
	[self release];
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

+(NSSet *)keyPathsForValuesAffectingIsLoaded {
	return [NSSet setWithObjects:@"tracksLoaded", @"albumsLoaded", @"artistsLoaded", nil];
}

-(BOOL)isLoaded {
	return self.tracksLoaded && self.artistsLoaded && self.albumsLoaded;
}

- (void)dealloc {
	self.locale = nil;
	self.username = nil;
	self.session = nil;
	self.tracks = nil;
	self.artists = nil;
	self.albums = nil;
	self.loadError = nil;
	
	if (artistBrowseOperation != NULL)
		sp_toplistbrowse_release(artistBrowseOperation);
	
	if (albumBrowseOperation != NULL)
		sp_toplistbrowse_release(albumBrowseOperation);
	
	if (trackBrowseOperation != NULL)
		sp_toplistbrowse_release(trackBrowseOperation);
	
    [super dealloc];
}

@end
