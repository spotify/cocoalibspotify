//
//  SPArtist.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/20/11.
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

#import "SPArtist.h"
#import "SPURLExtensions.h"
#import "SPSession.h"
#import "SPSessionInternal.h"

@interface SPArtist ()

-(BOOL)checkLoaded;
-(void)loadArtistData;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSURL *spotifyURL;
@property (nonatomic, readwrite) sp_artist *artist;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;

@end

@implementation SPArtist

static NSMutableDictionary *artistCache;

+(SPArtist *)artistWithArtistStruct:(sp_artist *)anArtist inSession:(SPSession *)aSession {
    
	SPAssertOnLibSpotifyThread();
	
    if (artistCache == nil) {
        artistCache = [[NSMutableDictionary alloc] init];
    }
    
    NSValue *ptrValue = [NSValue valueWithPointer:anArtist];
    SPArtist *cachedArtist = [artistCache objectForKey:ptrValue];
    
    if (cachedArtist != nil) {
        return cachedArtist;
    }
    
    cachedArtist = [[SPArtist alloc] initWithArtistStruct:anArtist inSession:aSession];
    
    [artistCache setObject:cachedArtist forKey:ptrValue];
    return cachedArtist;
}

+(void)artistWithArtistURL:(NSURL *)aURL inSession:(SPSession *)aSession callback:(void (^)(SPArtist *artist))block {
	
	if ([aURL spotifyLinkType] != SP_LINKTYPE_ARTIST) {
		if (block) block(nil);
		return;
	}
	
	dispatch_libspotify_async(^{
		SPArtist *newArtist = nil;
		sp_link *link = [aURL createSpotifyLink];
		if (link != NULL) {
			sp_artist *artist = sp_link_as_artist(link);
			sp_artist_add_ref(artist);
			newArtist = [self artistWithArtistStruct:artist inSession:aSession];
			sp_artist_release(artist);
			sp_link_release(link);
		}
		if (block) dispatch_async(dispatch_get_main_queue(), ^() { block(newArtist); });
	});
}

#pragma mark -

-(id)initWithArtistStruct:(sp_artist *)anArtist inSession:(SPSession *)aSession {
	
	SPAssertOnLibSpotifyThread();
	
    if ((self = [super init])) {
        self.artist = anArtist;
        sp_artist_add_ref(self.artist);
        sp_link *link = sp_link_create_from_artist(anArtist);
        if (link != NULL) {
            self.spotifyURL = [NSURL urlWithSpotifyLink:link];
            sp_link_release(link);
        }
		
		if (!sp_artist_is_loaded(self.artist)) {
            [aSession addLoadingObject:self];
        } else {
            [self loadArtistData];
        }

    }
    return self;
}



-(BOOL)checkLoaded {
	
	SPAssertOnLibSpotifyThread();
	
	BOOL isLoaded = sp_artist_is_loaded(self.artist);
	if (isLoaded) [self loadArtistData];
	
	return isLoaded;
}

-(void)loadArtistData {
	
	SPAssertOnLibSpotifyThread();
	
	NSString *newName = nil;
	
	const char *nameCharArray = sp_artist_name(self.artist);
	if (nameCharArray != NULL) {
		NSString *nameString = [NSString stringWithUTF8String:nameCharArray];
		newName = [nameString length] > 0 ? nameString : nil;
	} else {
		newName = nil;
	}
	
	BOOL isLoaded = sp_artist_is_loaded(self.artist);
	
	dispatch_async(dispatch_get_main_queue(), ^() {
		self.name = newName;
		self.loaded = isLoaded;
	});
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.name];
}

-(sp_artist *)artist {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif
	return _artist;
}

@synthesize artist = _artist;
@synthesize spotifyURL;
@synthesize name;
@synthesize loaded;

-(void)dealloc {
	sp_artist *outgoing_artist = _artist;
	_artist = NULL;
	dispatch_libspotify_async(^() { if (outgoing_artist) sp_artist_release(outgoing_artist); });
}

@end
