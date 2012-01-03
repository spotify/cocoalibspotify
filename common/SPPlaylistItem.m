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

#import "SPPlaylistItem.h"
#import "SPPlaylist.h"
#import "SPSession.h"
#import "SPUser.h"
#import "SPTrack.h"
#import "SPURLExtensions.h"

@interface SPPlaylistItem ()

@property (nonatomic, readwrite, retain) id <SPPlaylistableItem> item;
@property (nonatomic, readwrite, copy) NSDate *dateAdded;
@property (nonatomic, readwrite, retain) SPUser *creator;
@property (nonatomic, readwrite, copy) NSString *message;

@end

@implementation SPPlaylistItem (SPPlaylistItemInternal)

-(id)initWithPlaceholderTrack:(sp_track *)track atIndex:(int)index inPlaylist:(SPPlaylist *)aPlaylist {
	
	if ((self = [super init])) {
		playlist = aPlaylist;
		itemIndex = index;
		if (sp_track_is_placeholder(track)) {
			self.item = [playlist.session objectRepresentationForSpotifyURL:[NSURL urlWithSpotifyLink:sp_link_create_from_track(track, 0)] linkType:NULL];
		} else {
			self.item = [SPTrack trackForTrackStruct:track inSession:playlist.session];
		}
		
		self.dateAdded = [NSDate dateWithTimeIntervalSince1970:sp_playlist_track_create_time(playlist.playlist, index)];
		self.creator = [SPUser userWithUserStruct:sp_playlist_track_creator(playlist.playlist, index)
										inSession:playlist.session];
		
		const char *msg = sp_playlist_track_message(playlist.playlist, index);
		if (msg != NULL)
			self.message = [NSString stringWithUTF8String:msg];
		
	}
	return self;
}

-(int)itemIndex {
	return itemIndex;
}

-(void)setItemIndex:(int)index {
	itemIndex = index;
}

-(void)setDateCreatedFromLibSpotify:(NSDate *)date {
	self.dateAdded = date;
}

-(void)setCreatorFromLibSpotify:(SPUser *)user {
	self.creator = user;
}

-(void)setUnreadFromLibSpotify:(BOOL)unread {
	[self willChangeValueForKey:@"unread"];
	_unread = unread;
	[self didChangeValueForKey:@"unread"];
}

-(void)setMessageFromLibSpotify:(NSString *)msg {
	self.message = msg;
}

-(void)setItemIndexFromLibSpotify:(int)newIndex {
	itemIndex = newIndex;
}

@end

@implementation SPPlaylistItem



@synthesize item;
@synthesize dateAdded;
@synthesize creator;
@synthesize message;

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], [self.item description]];
}

+(NSSet *)keyPathsForValuesAffectingItemURL {
	return [NSSet setWithObject:@"item"];
}

-(NSURL *)itemURL {
	return [self.item spotifyURL];
}

+(NSSet *)keyPathsForValuesAffectingItemURLType {
	return [NSSet setWithObject:@"item"];
}

-(sp_linktype)itemURLType {
	return [[self.item spotifyURL] spotifyLinkType]; 
}

+(NSSet *)keyPathsForValuesAffectingItemClass {
	return [NSSet setWithObject:@"item"];
}

-(Class)itemClass {
	return [self.item class];
}

@synthesize unread = _unread;

-(void)setUnread:(BOOL)unread {
	sp_playlist_track_set_seen(playlist.playlist, itemIndex, !unread);
	_unread = unread;
}

-(void)dealloc {
	self.message = nil;
	self.creator = nil;
	self.dateAdded = nil;
	self.item = nil;
	playlist = nil;
	[super dealloc];
}

@end
