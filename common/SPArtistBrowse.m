//
//  SPArtistBrowse.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 4/24/11.
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

// IMPORTANT: This class was implemented while enjoying a lovely spring afternoon by a lake 
// in Sweden. This is my view right now:  http://twitpic.com/4oy9zn

#import "SPArtistBrowse.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPImage.h"
#import "SPSession.h"

@interface SPArtistBrowse ()

@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite, copy) NSError *loadError;
@property (nonatomic, readwrite, strong) SPArtist *artist;
@property (nonatomic, readwrite, strong) SPSession *session;

@property (nonatomic, readwrite, strong) NSArray *portraits;

@property (nonatomic, readwrite, strong) NSArray *tracks;
@property (nonatomic, readwrite, strong) NSArray *topTracks;
@property (nonatomic, readwrite, strong) NSArray *albums;
@property (nonatomic, readwrite, strong) NSArray *relatedArtists;

@property (nonatomic, readwrite, copy) NSString *biography;

@property (nonatomic, readwrite) sp_artistbrowse *artistBrowse;

@end

void artistbrowse_complete(sp_artistbrowse *result, void *userdata);
void artistbrowse_complete(sp_artistbrowse *result, void *userdata) {
	
	@autoreleasepool {
		
		// This is on the libSpotify thread
		
		SPArtistBrowse *artistBrowse = (__bridge_transfer SPArtistBrowse *)userdata;
		
		BOOL isLoaded = sp_artistbrowse_is_loaded(result);
		sp_error errorCode = sp_artistbrowse_error(result);
		NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
		
		NSString *newBio = nil;
		NSArray *newTracks = nil;
		NSArray *newTopTracks = nil;
		NSArray *newRelatedArtists = nil;
		NSArray *newAlbums = nil;
		NSArray *newPortraits = nil;
		
		if (isLoaded) {
			
			newBio = [NSString stringWithUTF8String:sp_artistbrowse_biography(result)];
			
			int trackCount = sp_artistbrowse_num_tracks(result);
			NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:trackCount];
			for (int currentTrack =  0; currentTrack < trackCount; currentTrack++) {
				sp_track *track = sp_artistbrowse_track(result, currentTrack);
				if (track != NULL) {
					[tracks addObject:[SPTrack trackForTrackStruct:track inSession:artistBrowse.session]];
				}
			}
			
			newTracks = [NSArray arrayWithArray:tracks];
			
			int topTrackCount = sp_artistbrowse_num_tophit_tracks(result);
			NSMutableArray *topTracks = [NSMutableArray arrayWithCapacity:topTrackCount];
			for (int currentTopTrack =  0; currentTopTrack < topTrackCount; currentTopTrack++) {
				sp_track *track = sp_artistbrowse_tophit_track(result, currentTopTrack);
				if (track != NULL) {
					[topTracks addObject:[SPTrack trackForTrackStruct:track inSession:artistBrowse.session]];
				}
			}
			
			newTopTracks = [NSArray arrayWithArray:topTracks];
			
			int albumCount = sp_artistbrowse_num_albums(result);
			NSMutableArray *albums = [NSMutableArray arrayWithCapacity:albumCount];
			for (int currentAlbum =  0; currentAlbum < albumCount; currentAlbum++) {
				sp_album *album = sp_artistbrowse_album(result, currentAlbum);
				if (album != NULL) {
					[albums addObject:[SPAlbum albumWithAlbumStruct:album inSession:artistBrowse.session]];
				}
			}
			
			newAlbums = [NSArray arrayWithArray:albums];
			
			int relatedArtistCount = sp_artistbrowse_num_similar_artists(result);
			NSMutableArray *relatedArtists = [NSMutableArray arrayWithCapacity:relatedArtistCount];
			for (int currentArtist =  0; currentArtist < relatedArtistCount; currentArtist++) {
				sp_artist *artist = sp_artistbrowse_similar_artist(result, currentArtist);
				if (artist != NULL) {
					[relatedArtists addObject:[SPArtist artistWithArtistStruct:artist inSession:artistBrowse.session]];
				}
			}
			
			newRelatedArtists = [NSArray arrayWithArray:relatedArtists];
			
			int portraitCount = sp_artistbrowse_num_portraits(result);
			NSMutableArray *portraits = [NSMutableArray arrayWithCapacity:portraitCount];
			for (int currentPortrait =  0; currentPortrait < portraitCount; currentPortrait++) {
				const byte *portraitId = sp_artistbrowse_portrait(result, currentPortrait);
				SPImage *portrait = [SPImage imageWithImageId:portraitId inSession:artistBrowse.session];
				if (portrait != nil) {
					[portraits addObject:portrait];
				}
			}
			
			newPortraits = [NSArray arrayWithArray:portraits];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			artistBrowse.loadError = error;
			artistBrowse.biography = newBio;
			artistBrowse.tracks = newTracks;
			artistBrowse.relatedArtists = newRelatedArtists;
			artistBrowse.albums = newAlbums;
			artistBrowse.portraits = newPortraits;
			artistBrowse.topTracks = newTopTracks;
			artistBrowse.loaded = isLoaded;
		});
	}
}

@implementation SPArtistBrowse

+(SPArtistBrowse *)browseArtist:(SPArtist *)anArtist inSession:(SPSession *)aSession type:(sp_artistbrowse_type)browseMode {
	return [[SPArtistBrowse alloc] initWithArtist:anArtist
										inSession:aSession
											 type:browseMode];
}

+(void)browseArtistAtURL:(NSURL *)artistURL inSession:(SPSession *)aSession type:(sp_artistbrowse_type)browseMode callback:(void (^)(SPArtistBrowse *artistBrowse))block {
	
	[SPArtist artistWithArtistURL:artistURL inSession:aSession callback:^(SPArtist *artist) {
		if (block) block([[SPArtistBrowse alloc] initWithArtist:artist inSession:aSession type:browseMode]);
	}];
}

-(id)initWithArtist:(SPArtist *)anArtist inSession:(SPSession *)aSession type:(sp_artistbrowse_type)browseMode {
	
	if (anArtist == nil || aSession == nil) {
		return nil;
	}
	
	if ((self = [super init])) {
		self.session = aSession;
		self.artist = anArtist;
		
		dispatch_libspotify_async(^{
			self.artistBrowse = sp_artistbrowse_create(aSession.session,
													   anArtist.artist,
													   browseMode,
													   &artistbrowse_complete,
													   (__bridge_retained void *)(self));
		});
	}
	
	return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.artist];
}

@synthesize loaded;
@synthesize loadError;
@synthesize artist;
@synthesize session;
@synthesize portraits;
@synthesize tracks;
@synthesize topTracks;
@synthesize albums;
@synthesize relatedArtists;
@synthesize biography;
@synthesize artistBrowse = _artistBrowse;

-(sp_artistbrowse *)artistBrowse {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif 
	return _artistBrowse;
}

+(NSSet *)keyPathsForValuesAffectingFirstPortrait {
	return [NSSet setWithObject:@"portraits"];
}

-(SPImage *)firstPortrait {
	if (self.portraits.count > 0) {
		return [self.portraits objectAtIndex:0];
	}
	return nil;
}

- (void)dealloc {
	sp_artistbrowse *outgoing_browse = _artistBrowse;
	_artistBrowse = NULL;
	dispatch_libspotify_async(^() { if (outgoing_browse) sp_artistbrowse_release(outgoing_browse); });
}

@end
