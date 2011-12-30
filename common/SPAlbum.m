//
//  SPAlbum.m
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

#import "SPAlbum.h"
#import "SPSession.h"
#import "SPImage.h"
#import "SPArtist.h"
#import "SPURLExtensions.h"

@interface SPAlbum ()

@property (readwrite) sp_album *album;
@property (readwrite, retain) SPSession *session;
@property (readwrite, retain) SPImage *cover; 
@property (readwrite, retain) SPArtist *artist;
@property (readwrite, copy) NSURL *spotifyURL;

-(void)loadAlbumData;

@end

@implementation SPAlbum

static NSMutableDictionary *albumCache;

+(SPAlbum *)albumWithAlbumStruct:(sp_album *)anAlbum inSession:(SPSession *)aSession {
    
    if (albumCache == nil) {
        albumCache = [[NSMutableDictionary alloc] init];
    }
    
    NSValue *ptrValue = [NSValue valueWithPointer:anAlbum];
    
    SPAlbum *cachedAlbum = [albumCache objectForKey:ptrValue];
    
    if (cachedAlbum != nil) {
        return cachedAlbum;
    }
    
    cachedAlbum = [[SPAlbum alloc] initWithAlbumStruct:anAlbum
                                                    inSession:aSession];
    
    [albumCache setObject:cachedAlbum forKey:ptrValue];
    return [cachedAlbum autorelease];
}

+(SPAlbum *)albumWithAlbumURL:(NSURL *)aURL inSession:(SPSession *)aSession {
	
	if ([aURL spotifyLinkType] == SP_LINKTYPE_ALBUM) {
		sp_link *link = [aURL createSpotifyLink];
		if (link != NULL) {
			sp_album *album = sp_link_as_album(link);
			sp_album_add_ref(album);
			SPAlbum *spAlbum = [self albumWithAlbumStruct:album inSession:aSession];
			sp_link_release(link);
			sp_album_release(album);
			return spAlbum;
		}
	}
	return nil;
}

-(id)initWithAlbumStruct:(sp_album *)anAlbum inSession:(SPSession *)aSession {
    if ((self = [super init])) {
        album = anAlbum;
        sp_album_add_ref(album);
        self.session = aSession;
        sp_link *link = sp_link_create_from_album(anAlbum);
        if (link != NULL) {
            self.spotifyURL = [NSURL urlWithSpotifyLink:link];
            sp_link_release(link);
        }
        
        if (!sp_album_is_loaded(album)) {
            [self performSelector:@selector(checkLoaded)
                       withObject:nil
                       afterDelay:.25];
        } else {
            [self loadAlbumData];
        }
    }
    return self;
}

-(void)checkLoaded {
    BOOL loaded = sp_album_is_loaded(album);
    if (!loaded) {
        [self performSelector:_cmd
                   withObject:nil
                   afterDelay:.25];
    } else {
        [self loadAlbumData];        
    }
}

-(void)loadAlbumData {
    const byte *imageId = sp_album_cover(album);
    
    if (imageId != NULL) {
        [self setCover:[SPImage imageWithImageId:imageId
                                              inSession:session]];
    }
    
    sp_artist *spArtist = sp_album_artist(album);
    if (spArtist != NULL) {
        [self setArtist:[SPArtist artistWithArtistStruct:spArtist]];
    }
    
    // Fire KVO notifications
    [self willChangeValueForKey:@"year"];
    [self didChangeValueForKey:@"year"];
    
    [self willChangeValueForKey:@"type"];
    [self didChangeValueForKey:@"type"];
    
    [self willChangeValueForKey:@"name"];
    [self didChangeValueForKey:@"name"];
    
    [self willChangeValueForKey:@"available"];
    [self didChangeValueForKey:@"available"];
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@ by %@", [super description], self.name, self.artist.name];
}

@synthesize album;
@synthesize session;
@synthesize cover;
@synthesize artist;
@synthesize spotifyURL;

-(BOOL)isAvailable {
    return (BOOL)sp_album_is_available(album);
}

-(BOOL)isLoaded {
    return (BOOL)sp_album_is_loaded(album);
}

-(NSUInteger)year {
    return (NSUInteger)sp_album_year(album);
}

-(sp_albumtype)type {
    return sp_album_type(album);
}

-(NSString *)name {
    const char *name = sp_album_name(album);
    if (name != NULL) {
        NSString *nameString = [NSString stringWithUTF8String:name];
        return [nameString length] > 0 ? nameString : nil;
    } else {
        return nil;
    }
}

-(void)dealloc {
    
    self.spotifyURL = nil;
    self.session = nil;
    [self setCover:nil];
    [self setArtist:nil];
    
    sp_album_release(album);
    
    [super dealloc];
}

@end
