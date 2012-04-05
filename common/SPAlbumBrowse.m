//
//  SPAlbumBrowse.m
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

#import "SPAlbumBrowse.h"
#import "SPSession.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"

// IMPORTANT: This class was implemented while enjoying a lovely spring afternoon by a lake 
// in Sweden. This is my view right now:  http://twitpic.com/4oy9zn

@interface SPAlbum (SPAlbumBrowseExtensions)
-(void)albumBrowseDidLoad;
@end

@interface SPTrack (SPAlbumBrowseExtensions)
-(void)albumBrowseDidLoad;
@end

@interface SPAlbumBrowse ()

@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite, copy) NSError *loadError;
@property (nonatomic, readwrite, strong) SPSession *session;

@property (nonatomic, readwrite, strong) SPAlbum *album;
@property (nonatomic, readwrite, strong) SPArtist *artist;
@property (nonatomic, readwrite, strong) NSArray *tracks;

@property (nonatomic, readwrite, strong) NSArray *copyrights;
@property (nonatomic, readwrite, copy) NSString *review;

@end

void albumbrowse_complete (sp_albumbrowse *result, void *userdata);
void albumbrowse_complete (sp_albumbrowse *result, void *userdata) {
	
	@autoreleasepool {
		
		SPAlbumBrowse *albumBrowse = (__bridge SPAlbumBrowse *)userdata;
		sp_error errorCode = sp_albumbrowse_error(result);
		
		if (errorCode != SP_ERROR_OK) {
			albumBrowse.loadError = [NSError spotifyErrorWithCode:errorCode];
		} else {
			albumBrowse.loadError = nil;
		}
		
		BOOL loaded = sp_albumbrowse_is_loaded(result);
		
		if (loaded) {
			
			sp_error errorCode = sp_albumbrowse_error(result);
			
			if (errorCode != SP_ERROR_OK) {
				albumBrowse.loadError = [NSError spotifyErrorWithCode:errorCode];
			} else {
				albumBrowse.loadError = nil;
			}
			
			albumBrowse.review = [NSString stringWithUTF8String:sp_albumbrowse_review(result)];
			albumBrowse.artist = [SPArtist artistWithArtistStruct:sp_albumbrowse_artist(result) inSession:albumBrowse.session];
			
			int trackCount = sp_albumbrowse_num_tracks(result);
			NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:trackCount];
			for (int currentTrack =  0; currentTrack < trackCount; currentTrack++) {
				sp_track *track = sp_albumbrowse_track(result, currentTrack);
				if (track != NULL) {
					SPTrack *aTrack = [SPTrack trackForTrackStruct:track inSession:albumBrowse.session];
					[aTrack albumBrowseDidLoad];
					[tracks addObject:aTrack];
				}
			}
			
			albumBrowse.tracks = [NSArray arrayWithArray:tracks];
			
			int copyrightCount = sp_albumbrowse_num_copyrights(result);
			NSMutableArray *copyrights = [NSMutableArray arrayWithCapacity:copyrightCount];
			for (int currentCopyright =  0; currentCopyright < copyrightCount; currentCopyright++) {
				const char *copyright = sp_albumbrowse_copyright(result, currentCopyright);
				[copyrights addObject:[NSString stringWithUTF8String:copyright]];
			}
			
			albumBrowse.copyrights = [NSArray arrayWithArray:copyrights];
			
			[albumBrowse.album albumBrowseDidLoad];
		}
		albumBrowse.loaded = loaded;
	}
}

@implementation SPAlbumBrowse {
	sp_albumbrowse *browseOperation;
}

+(SPAlbumBrowse *)browseAlbum:(SPAlbum *)anAlbum inSession:(SPSession *)aSession {
	return [[SPAlbumBrowse alloc] initWithAlbum:anAlbum inSession:aSession];
}

+(SPAlbumBrowse *)browseAlbumAtURL:(NSURL *)albumURL inSession:(SPSession *)aSession {
	return [[SPAlbumBrowse alloc] initWithAlbum:[SPAlbum albumWithAlbumURL:albumURL inSession:aSession] 
									  inSession:aSession];
	
}

-(id)initWithAlbum:(SPAlbum *)anAlbum inSession:(SPSession *)aSession; {
	
	if (anAlbum == nil || aSession == nil) {
		return nil;
	}
	
	if ((self = [super init])) {
		self.session = aSession;
		self.album = anAlbum;
		
		sp_albumbrowse *albumBrowse = sp_albumbrowse_create(self.session.session,
															self.album.album,
															&albumbrowse_complete,
															(__bridge void *)(self));
		if (albumBrowse != NULL) {
			browseOperation = albumBrowse;
		}
	}
	
	return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.album];
}

@synthesize loaded;
@synthesize loadError;
@synthesize session;
@synthesize album;
@synthesize artist;
@synthesize tracks;
@synthesize copyrights;
@synthesize review;

- (void)dealloc {
	
	if (browseOperation != NULL)
		sp_albumbrowse_release(browseOperation);
	
}

@end
