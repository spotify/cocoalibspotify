//
//  SPTrack.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/19/11.
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

#import "SPTrack.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPSession.h"
#import "SPURLExtensions.h"

static const NSTimeInterval kCheckLoadedDuration = .25;

@interface SPTrack ()

-(void)loadTrackData;

@property (readwrite, retain) SPAlbum *album;
@property (readwrite, retain) NSArray *artists;
@property (readwrite, copy) NSURL *spotifyURL;

@end

@implementation SPTrack

+(SPTrack *)trackForTrackStruct:(sp_track *)spTrack inSession:(SPSession *)aSession{
    return [aSession trackForTrackStruct:spTrack];
}

+(SPTrack *)trackForTrackURL:(NSURL *)trackURL inSession:(SPSession *)aSession {
	return [aSession trackForURL:trackURL];
}

-(id)initWithTrackStruct:(sp_track *)tr inSession:(SPSession *)aSession {
    if ((self = [super init])) {
        session = aSession;
        track = tr;
        sp_track_add_ref(track);
        
        if (!sp_track_is_loaded(track)) {
            [self performSelector:@selector(checkLoaded)
                       withObject:nil
                       afterDelay:kCheckLoadedDuration];
        } else {
            [self loadTrackData];
        }
    }   
    return self;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@: %@", [super description], [self name]];
}
         
-(void)checkLoaded {
    BOOL loaded = sp_track_is_loaded(track);
    if (!loaded) {
        [self performSelector:_cmd
                   withObject:nil
                   afterDelay:kCheckLoadedDuration];
    } else {
        [self loadTrackData];
    }
}

-(void)loadTrackData {
	
	sp_link *link = sp_link_create_from_track(track, 0);
	if (link != NULL) {
		[self setSpotifyURL:[NSURL urlWithSpotifyLink:link]];
		sp_link_release(link);
	}
    
    sp_album *spAlbum = sp_track_album(track);
    
    if (spAlbum != NULL) {
        [self setAlbum:[SPAlbum albumWithAlbumStruct:spAlbum
                                                  inSession:session]];
    }
    
    NSUInteger artistCount = sp_track_num_artists(track);
    
    if (artistCount > 0) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:artistCount];
        NSUInteger currentArtist = 0;
        for (currentArtist = 0; currentArtist < artistCount; currentArtist++) {
            sp_artist *artist = sp_track_artist(track, (int)currentArtist);
            if (artist != NULL) {
                [array addObject:[SPArtist artistWithArtistStruct:artist]];
            }
        }
        
        if ([array count] > 0) {
            [self setArtists:[NSArray arrayWithArray:array]];
        }
    }
    
    // Fire KVO notifications
    [self willChangeValueForKey:@"trackNumber"];
    [self didChangeValueForKey:@"trackNumber"];
    
    [self willChangeValueForKey:@"discNumber"];
    [self didChangeValueForKey:@"discNumber"];
    
    [self willChangeValueForKey:@"popularity"];
    [self didChangeValueForKey:@"popularity"];
    
    [self willChangeValueForKey:@"duration"];
    [self didChangeValueForKey:@"duration"];
    
    [self willChangeValueForKey:@"name"];
    [self didChangeValueForKey:@"name"];
    
    [self willChangeValueForKey:@"availableForPlayback"];
    [self didChangeValueForKey:@"availableForPlayback"];
    
    [self willChangeValueForKey:@"starred"];
    [self didChangeValueForKey:@"starred"];
	
	[self willChangeValueForKey:@"loaded"];
    [self didChangeValueForKey:@"loaded"];
}

#pragma mark -
#pragma mark Properties 

@synthesize album;
@synthesize artists;

+(NSSet *)keyPathsForValuesAffectingConsolidatedArtists {
	return [NSSet setWithObject:@"artists"];
}

-(NSString *)consolidatedArtists {
	if (self.artists.count == 0)
		return nil;
	
	return [[[self.artists valueForKey:@"name"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@", "];
}

-(NSUInteger)trackNumber {
    return (NSUInteger)sp_track_index(track);
}

-(NSUInteger)discNumber {
    return (NSUInteger)sp_track_disc(track);
}

-(NSUInteger)popularity {
    return (NSUInteger)sp_track_popularity(track);
}

-(NSTimeInterval)duration {
    return (NSTimeInterval)(double)sp_track_duration(track) / 1000.0;
}

-(NSString *)name {
    const char *name = sp_track_name(track);
    if (name != NULL) {
        NSString *nameString = [NSString stringWithUTF8String:name];
        return [nameString length] > 0 ? nameString : nil;
    } else {
        return nil;
    }
}

-(sp_track_availability)availability {
    return sp_track_get_availability([session session], track);
}

-(BOOL)isLoaded {
	return sp_track_is_loaded(track);
}

-(BOOL)starred {
    return sp_track_is_starred([session session], track);
}

-(void)setStarred:(BOOL)starred {
    sp_track_set_starred([session session], (sp_track *const *)&track, 1, starred);
}

-(sp_track_offline_status)offlineStatus {
	return sp_track_offline_get_status(self.track);
}

@synthesize spotifyURL;
@synthesize track;

-(void)dealloc {
    
    [self setAlbum:nil];
    [self setArtists:nil];
    
    sp_track_release(track);
    session = nil;
    
    [super dealloc];
}

@end
