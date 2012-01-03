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
#import "SPTrackInternal.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPSession.h"
#import "SPURLExtensions.h"

static const NSTimeInterval kCheckLoadedDuration = .25;

@interface SPTrack ()

-(void)checkLoaded;
-(void)loadTrackData;

@property (nonatomic, readwrite, retain) SPAlbum *album;
@property (nonatomic, readwrite, retain) NSArray *artists;
@property (nonatomic, readwrite, copy) NSURL *spotifyURL;

@property (nonatomic, readwrite) sp_track_availability availability;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite) sp_track_offline_status offlineStatus;
@property (nonatomic, readwrite) NSUInteger discNumber;
@property (nonatomic, readwrite) NSTimeInterval duration;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite) NSUInteger popularity;
@property (nonatomic, readwrite) NSUInteger trackNumber;
@property (nonatomic, readwrite, getter = isLocal) BOOL local;

@property (nonatomic, assign, readwrite) __weak SPSession *session;
	
@end

@implementation SPTrack (SPTrackInternal)

-(void)setStarredFromLibSpotifyUpdate:(BOOL)starred {
	[self willChangeValueForKey:@"starred"];
	_starred = starred;
	[self didChangeValueForKey:@"starred"];
}

-(void)setOfflineStatusFromLibSpotifyUpdate:(sp_track_offline_status)status {
	self.offlineStatus = status;
}

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
        self.session = aSession;
        track = tr;
        sp_track_add_ref(track);
        
        [self checkLoaded];
    }   
    return self;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@: %@", [super description], [self name]];
}
         
-(void)checkLoaded {
    if (!sp_track_is_loaded(track)) {
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
    
	self.local = sp_track_is_local(session.session, track);
	self.trackNumber = sp_track_index(track);
	self.discNumber = sp_track_disc(track);
	self.popularity = sp_track_popularity(track);
	self.duration = (NSTimeInterval)sp_track_duration(track) / 1000.0;
	self.availability = sp_track_get_availability(self.session.session, track);
	self.offlineStatus = sp_track_offline_get_status(track);
	self.loaded = sp_track_is_loaded(track);
	[self setStarredFromLibSpotifyUpdate:sp_track_is_starred(self.session.session, track)];
	
	const char *nameCharArray = sp_track_name(track);
    if (nameCharArray != NULL) {
        NSString *nameString = [NSString stringWithUTF8String:nameCharArray];
        self.name = [nameString length] > 0 ? nameString : nil;
    } else {
        self.name = nil;
    }
}

#pragma mark -
#pragma mark Properties 

@synthesize album;
@synthesize artists;
@synthesize trackNumber;
@synthesize discNumber;
@synthesize popularity;
@synthesize duration;
@synthesize availability;
@synthesize offlineStatus;
@synthesize loaded;
@synthesize name;
@synthesize session;
@synthesize starred = _starred;
@synthesize local;

+(NSSet *)keyPathsForValuesAffectingConsolidatedArtists {
	return [NSSet setWithObject:@"artists"];
}

-(NSString *)consolidatedArtists {
	if (self.artists.count == 0)
		return nil;
	
	return [[[self.artists valueForKey:@"name"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@", "];
}

-(void)setStarred:(BOOL)starred {
    sp_track_set_starred([session session], (sp_track *const *)&track, 1, starred);
	_starred = starred;
}

@synthesize spotifyURL;
@synthesize track;

-(void)dealloc {
    
	[self setName:nil];
    [self setAlbum:nil];
    [self setArtists:nil];
    
    sp_track_release(track);
    session = nil;
    
    [super dealloc];
}

@end
