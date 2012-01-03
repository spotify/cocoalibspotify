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

@interface SPArtist ()

-(void)checkLoaded;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSURL *spotifyURL;

@end

@implementation SPArtist

static NSMutableDictionary *artistCache;

+(SPArtist *)artistWithArtistStruct:(sp_artist *)anArtist {
    
    if (artistCache == nil) {
        artistCache = [[NSMutableDictionary alloc] init];
    }
    
    NSValue *ptrValue = [NSValue valueWithPointer:anArtist];
    SPArtist *cachedArtist = [artistCache objectForKey:ptrValue];
    
    if (cachedArtist != nil) {
        return cachedArtist;
    }
    
    cachedArtist = [[SPArtist alloc] initWithArtistStruct:anArtist];
    
    [artistCache setObject:cachedArtist forKey:ptrValue];
    return [cachedArtist autorelease];
}

+(SPArtist *)artistWithArtistURL:(NSURL *)aURL {
	
	if ([aURL spotifyLinkType] == SP_LINKTYPE_ARTIST) {
		sp_link *link = [aURL createSpotifyLink];
		if (link != NULL) {
			sp_artist *artist = sp_link_as_artist(link);
			sp_artist_add_ref(artist);
			SPArtist *spArtist = [self artistWithArtistStruct:artist];
			sp_artist_release(artist);
			sp_link_release(link);
			return spArtist;
		}
	}
	return nil;
}

#pragma mark -

-(id)initWithArtistStruct:(sp_artist *)anArtist {
    if ((self = [super init])) {
        artist = anArtist;
        sp_artist_add_ref(artist);
        sp_link *link = sp_link_create_from_artist(anArtist);
        if (link != NULL) {
            self.spotifyURL = [NSURL urlWithSpotifyLink:link];
            sp_link_release(link);
        }

        [self checkLoaded];
    }
    return self;
}

-(void)checkLoaded {
    BOOL loaded = sp_artist_is_loaded(artist);
    if (!loaded) {
        [self performSelector:_cmd
                   withObject:nil
                   afterDelay:.25];
    } else {
        
        const char *nameCharArray = sp_artist_name(artist);
		if (nameCharArray != NULL) {
			NSString *nameString = [NSString stringWithUTF8String:nameCharArray];
			self.name = [nameString length] > 0 ? nameString : nil;
		} else {
			self.name = nil;
		}
    }
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.name];
}

@synthesize artist;
@synthesize spotifyURL;
@synthesize name;

-(void)dealloc {
	self.name = nil;
    self.spotifyURL = nil;
    sp_artist_release(artist);
    [super dealloc];
}

@end
