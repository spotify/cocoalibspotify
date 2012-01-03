//
//  SPPlaylist.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/14/11.
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

#import "SPPlaylist.h"
#import "SPPlaylistInternal.h"
#import "SPSession.h"
#import "SPTrack.h"
#import "SPTrackInternal.h"
#import "SPImage.h"
#import "SPUser.h"
#import "SPURLExtensions.h"
#import "SPErrorExtensions.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistItemInternal.h"

@interface SPPlaylist ()

@property (nonatomic, readwrite, getter=isUpdating) BOOL updating;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite) BOOL hasPendingChanges;
@property (nonatomic, readwrite, copy) NSString *playlistDescription;
@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, retain) SPImage *image;
@property (nonatomic, readwrite, retain) SPUser *owner;
@property (nonatomic, readwrite) BOOL trackChangesAreFromLibSpotifyCallback;
@property (nonatomic, readwrite, retain) NSMutableArray *itemWrapper;
@property (nonatomic, readwrite, retain) NSArray *subscribers;
@property (nonatomic, readwrite) float offlineDownloadProgress;
@property (nonatomic, readwrite) sp_playlist_offline_status offlineStatus;

-(void)rebuildItems;
-(void)loadPlaylistData;
-(void)rebuildSubscribers;
-(void)resetItemIndexes;

-(void)setPlaylistNameFromLibSpotifyUpdate:(NSString *)newName;
-(void)setPlaylistDescriptionFromLibSpotifyUpdate:(NSString *)newDescription;
-(void)setCollaborativeFromLibSpotifyUpdate:(BOOL)collaborative;

@end

#pragma mark Callbacks

// Called when one or more tracks have been added to a playlist
static void tracks_added(sp_playlist *pl, sp_track *const *tracks, int num_tracks, int position, void *userdata) {
    
	SPPlaylist *playlist = userdata;
	
	NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:num_tracks];
	
	for (NSUInteger currentItem = 0; currentItem < num_tracks; currentItem++) {
		sp_track *thisTrack = tracks[currentItem];
		if (thisTrack != NULL) {
			[newItems addObject:[[[SPPlaylistItem alloc] initWithPlaceholderTrack:thisTrack
																		  atIndex:(int)position + (int)currentItem
																	   inPlaylist:playlist] autorelease]];
		}
	}
	
	NSIndexSet *incomingIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(position, [newItems count])];
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:willAddItems:atIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist willAddItems:newItems atIndexes:incomingIndexes];
	}
	
	playlist.trackChangesAreFromLibSpotifyCallback = YES;
	[playlist.items insertObjects:newItems atIndexes:incomingIndexes];
	playlist.trackChangesAreFromLibSpotifyCallback = NO;
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:didAddItems:atIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist didAddItems:newItems atIndexes:incomingIndexes];
	}
}

// Called when one or more tracks have been removed from a playlist
static void	tracks_removed(sp_playlist *pl, const int *tracks, int num_tracks, void *userdata) {

	SPPlaylist *playlist = userdata;	
	
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	
	for (NSUInteger currentIndex = 0; currentIndex < num_tracks; currentIndex++) {
		int thisIndex = tracks[currentIndex];
		[indexes addIndex:thisIndex];
	}
	
	NSArray *outgoingItems = [playlist.items objectsAtIndexes:indexes];
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:willRemoveItems:atIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist willRemoveItems:outgoingItems atIndexes:indexes];
	}
	
	playlist.trackChangesAreFromLibSpotifyCallback = YES;
	[playlist.items removeObjectsAtIndexes:indexes];
	playlist.trackChangesAreFromLibSpotifyCallback = NO;
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:didRemoveItems:atIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist didRemoveItems:outgoingItems atIndexes:indexes];
	}
}

// Called when one or more tracks have been moved within a playlist
static void	tracks_moved(sp_playlist *pl, const int *tracks, int num_tracks, int new_position, void *userdata) {
    
	SPPlaylist *playlist = userdata;
	
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	NSUInteger newStartIndex = new_position;
	
	for (NSUInteger currentIndex = 0; currentIndex < num_tracks; currentIndex++) {
		int thisIndex = tracks[currentIndex];
		[indexes addIndex:thisIndex];
		if (thisIndex < new_position) {
			newStartIndex--;
		}
	}
	
	NSMutableArray *playlistItems = playlist.items;
	NSArray *movedItems = [playlistItems objectsAtIndexes:indexes];
	NSMutableIndexSet *newIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(newStartIndex, [movedItems count])];
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:willMoveItems:atIndexes:toIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist willMoveItems:movedItems atIndexes:indexes toIndexes:newIndexes];
	}
	
	NSMutableArray *newItemArray = [NSMutableArray arrayWithArray:playlistItems];
	[newItemArray removeObjectsAtIndexes:indexes];
	[newItemArray insertObjects:movedItems atIndexes:newIndexes];
	
	playlist.trackChangesAreFromLibSpotifyCallback = YES;
	[playlist willChangeValueForKey:@"items"];
	playlist.itemWrapper = newItemArray;
	[playlist resetItemIndexes];
	[playlist didChangeValueForKey:@"items"];
	playlist.trackChangesAreFromLibSpotifyCallback = NO;
	
	if ([[playlist delegate] respondsToSelector:@selector(playlist:didMoveItems:atIndexes:toIndexes:)]) {
		[(id <SPPlaylistDelegate>)[playlist delegate] playlist:playlist didMoveItems:movedItems atIndexes:indexes toIndexes:newIndexes];
	}
}

// Called when a playlist has been renamed. sp_playlist_name() can be used to find out the new name
static void	playlist_renamed(sp_playlist *pl, void *userdata) {
    NSString *name = [NSString stringWithUTF8String:sp_playlist_name(pl)];
    [(SPPlaylist *)userdata setPlaylistNameFromLibSpotifyUpdate:name];
}

/*
 Called when state changed for a playlist.
 
 There are three states that trigger this callback:
 
 Collaboration for this playlist has been turned on or off
 The playlist started having pending changes, or all pending changes have now been committed
 The playlist started loading, or finished loading
 */
static void	playlist_state_changed(sp_playlist *pl, void *userdata) {
    SPPlaylist *playlist = userdata;
	
    [playlist setLoaded:sp_playlist_is_loaded(pl)];
    [playlist setCollaborativeFromLibSpotifyUpdate:sp_playlist_is_collaborative(pl)];
    [playlist setHasPendingChanges:sp_playlist_has_pending_changes(pl)];
	
	[playlist offlineSyncStatusMayHaveChanged];
}

// Called when a playlist is updating or is done updating
static void	playlist_update_in_progress(sp_playlist *pl, bool done, void *userdata) {
    SPPlaylist *playlist = userdata;
	
	if (playlist.isUpdating == done && [playlist playlist] == pl)
		playlist.updating = !done;
}

// Called when metadata for one or more tracks in a playlist has been updated.
static void	playlist_metadata_updated(sp_playlist *pl, void *userdata) {
    SPPlaylist *playlist = userdata;
    
	for (SPPlaylistItem *playlistItem in playlist.items) {
		if (playlistItem.itemClass == [SPTrack class]) {
			SPTrack *track = playlistItem.item;
			[track setOfflineStatusFromLibSpotifyUpdate:sp_track_offline_get_status(track.track)];
		}
	}
	
    SEL selector = @selector(itemsInPlaylistDidUpdateMetadata:);
    
    if ([[playlist delegate] respondsToSelector:selector]) {
        
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [[playlist delegate] performSelector:selector
                                  withObject:playlist];
        [pool drain];
    }
    
}

// Called when create time and/or creator for a playlist entry changes
static void	track_created_changed(sp_playlist *pl, int position, sp_user *user, int when, void *userdata) {
    
	SPPlaylist *playlist = userdata;
	SPPlaylistItem *item = [playlist.items objectAtIndex:position];
	
	[item setDateCreatedFromLibSpotify:[NSDate dateWithTimeIntervalSince1970:when]];
	[item setCreatorFromLibSpotify:[SPUser userWithUserStruct:user inSession:playlist.session]];
}

// Called when seen attribute for a playlist entry changes
static void	track_seen_changed(sp_playlist *pl, int position, bool seen, void *userdata) {
    
	SPPlaylist *playlist = userdata;
	SPPlaylistItem *item = [playlist.items objectAtIndex:position];
	
	[item setUnreadFromLibSpotify:!seen];
}

// Called when playlist description has changed
static void	description_changed(sp_playlist *pl, const char *desc, void *userdata) {
    SPPlaylist *playlist = userdata;
    [playlist setPlaylistDescriptionFromLibSpotifyUpdate:[NSString stringWithUTF8String:desc]];
}

static void	image_changed(sp_playlist *pl, const byte *image, void *userdata) {
    SPPlaylist *playlist = userdata;
    [playlist setImage:[SPImage imageWithImageId:image inSession:[playlist session]]];
}

// Called when message attribute for a playlist entry changes
static void	track_message_changed(sp_playlist *pl, int position, const char *message, void *userdata) {

	SPPlaylist *playlist = userdata;
	SPPlaylistItem *item = [playlist.items objectAtIndex:position];
	
	if (message != NULL)
		[item setMessageFromLibSpotify:[NSString stringWithUTF8String:message]];
	else
		[item setMessageFromLibSpotify:nil];
}

// Called when playlist subscribers changes (count or list of names)
static void	subscribers_changed(sp_playlist *pl, void *userdata) {
    SPPlaylist *playlist = userdata;
	[playlist rebuildSubscribers];
}

static sp_playlist_callbacks _playlistCallbacks = {
	&tracks_added,
	&tracks_removed,
	&tracks_moved,
	&playlist_renamed,
	&playlist_state_changed,
	&playlist_update_in_progress,
	&playlist_metadata_updated,
	&track_created_changed,
	&track_seen_changed,
	&description_changed,
    &image_changed,
    &track_message_changed,
    &subscribers_changed
};


#pragma mark -

static NSString * const kSPPlaylistKVOContext = @"kSPPlaylistKVOContext";

@implementation SPPlaylist (SPPlaylistInternal)

-(void)offlineSyncStatusMayHaveChanged {
	
	self.offlineStatus = sp_playlist_get_offline_status(self.session.session, self.playlist);
	self.offlineDownloadProgress = sp_playlist_get_offline_download_completed(self.session.session, self.playlist) / 100.0;
}

@end

@implementation SPPlaylist

+(SPPlaylist *)playlistWithPlaylistStruct:(sp_playlist *)pl inSession:(SPSession *)aSession {
	return [aSession playlistForPlaylistStruct:pl];
}

+(SPPlaylist *)playlistWithPlaylistURL:(NSURL *)playlistURL inSession:(SPSession *)aSession {
	return [aSession playlistForURL:playlistURL];
}

-(id)initWithPlaylistStruct:(sp_playlist *)pl inSession:(SPSession *)aSession {
    
    if ((self = [super init])) {
        session = aSession;
        playlist = pl;
		itemWrapper = [[NSMutableArray alloc] init];

		// Add Observers
        
        [self addObserver:self
               forKeyPath:@"name"
                  options:0
                  context:kSPPlaylistKVOContext];
        
        [self addObserver:self
               forKeyPath:@"playlistDescription"
                  options:0
                  context:kSPPlaylistKVOContext];
        
        [self addObserver:self
               forKeyPath:@"collaborative"
                  options:0
                  context:kSPPlaylistKVOContext];
        
        [self addObserver:self
               forKeyPath:@"loaded"
                  options:NSKeyValueObservingOptionOld
                  context:kSPPlaylistKVOContext];
		
		if (playlist != NULL) {
			sp_playlist_add_ref(pl);
			sp_playlist_add_callbacks(playlist, &_playlistCallbacks, (void *)self);
			sp_playlist_set_in_ram(aSession.session, playlist, true);
			self.loaded = sp_playlist_is_loaded(pl);
		}
        
    }
    return self;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@: %@ (%d items)", [super description], [self name], [[self valueForKey:@"items"] count]];
}

@synthesize playlist;
@synthesize updating;
@synthesize playlistDescription;
@synthesize delegate;
@synthesize name;
@synthesize loaded;
@synthesize collaborative;
@synthesize hasPendingChanges;
@synthesize spotifyURL;
@synthesize image;
@synthesize session;
@synthesize owner;
@synthesize itemWrapper;
@synthesize subscribers;

@dynamic items;
@synthesize trackChangesAreFromLibSpotifyCallback;

-(void)setMarkedForOfflinePlayback:(BOOL)isMarkedForOfflinePlayback {
	sp_playlist_set_offline_mode(self.session.session, self.playlist, isMarkedForOfflinePlayback);
}

-(BOOL)isMarkedForOfflinePlayback {
	return self.offlineStatus != SP_PLAYLIST_OFFLINE_STATUS_NO;
}

@synthesize offlineDownloadProgress;
@synthesize offlineStatus;

#pragma mark -
#pragma mark Private Methods

-(void)loadPlaylistData {
	
	if (playlist == NULL)
		return;
    
	sp_link *link = sp_link_create_from_playlist(playlist);
	if (link != NULL) {
		[self setSpotifyURL:[NSURL urlWithSpotifyLink:link]];
		sp_link_release(link);
	}

    const char *nameBuf = sp_playlist_name(playlist);
    
    if (nameBuf != NULL) {
        [self setPlaylistNameFromLibSpotifyUpdate:[NSString stringWithUTF8String:nameBuf]];
    }
    
    const char *desc = sp_playlist_get_description(playlist);
    
    if (desc != NULL) {
        [self setPlaylistDescriptionFromLibSpotifyUpdate:[NSString stringWithUTF8String:desc]];
    }
    
    byte imageId[20];
    if (sp_playlist_get_image(playlist, imageId)) {
        [self setImage:[SPImage imageWithImageId:imageId
                                              inSession:session]];
    }
    
    [self setOwner:[SPUser userWithUserStruct:sp_playlist_owner(playlist) inSession:session]];
    [self setCollaborativeFromLibSpotifyUpdate:sp_playlist_is_collaborative(playlist)];
    [self setHasPendingChanges:sp_playlist_has_pending_changes(playlist)];
	[self offlineSyncStatusMayHaveChanged];
    
	[self rebuildItems];
	sp_playlist_update_subscribers(self.session.session, self.playlist);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (context == kSPPlaylistKVOContext) {
        if ([keyPath isEqualToString:@"name"]) {
            sp_playlist_rename(playlist, [[self name] UTF8String]);
            return;
        } else if ([keyPath isEqualToString:@"collaborative"]) {
            sp_playlist_set_collaborative(playlist, [self isCollaborative]);
            return;
        } else if ([keyPath isEqualToString:@"loaded"]) {
            
			if (self.isLoaded) {
                [self loadPlaylistData];
            }
            return;
        }
    } 
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(void)setPlaylistNameFromLibSpotifyUpdate:(NSString *)newName {
    // Remove observers otherwise we'll create an infinite loop!
    [self removeObserver:self forKeyPath:@"name"];
    [self setName:newName];
    [self addObserver:self
           forKeyPath:@"name"
              options:0
              context:kSPPlaylistKVOContext];
}

-(void)setPlaylistDescriptionFromLibSpotifyUpdate:(NSString *)newDescription {
    // Remove observers otherwise we'll create an infinite loop!
    [self removeObserver:self forKeyPath:@"playlistDescription"];
    [self setPlaylistDescription:newDescription];
    [self addObserver:self
           forKeyPath:@"playlistDescription"
              options:0
              context:kSPPlaylistKVOContext];
}

-(void)setCollaborativeFromLibSpotifyUpdate:(BOOL)newCollaborative {
    // Remove observers otherwise we'll create an infinite loop!
    [self removeObserver:self forKeyPath:@"collaborative"];
    [self setCollaborative:newCollaborative];
    [self addObserver:self
           forKeyPath:@"collaborative"
              options:0
              context:kSPPlaylistKVOContext];
}

#pragma mark -

-(void)rebuildSubscribers {
	
	NSUInteger subscriberCount = sp_playlist_num_subscribers(self.playlist);
	
	if (subscriberCount > 0) {
	
		sp_subscribers *subs = sp_playlist_subscribers(self.playlist);
		NSUInteger actualSubscriberCount = subs->count;
		NSMutableArray *newSubscribers = [NSMutableArray arrayWithCapacity:actualSubscriberCount];
		
		for (NSUInteger currentSubscriber = 0; currentSubscriber < actualSubscriberCount; currentSubscriber++) {
			
			char *subscriberName = subs->subscribers[currentSubscriber];
			if (subscriberName != NULL && strlen(subscriberName) > 0) {
				NSString *subsName = [NSString stringWithUTF8String:subscriberName];
				if (subsName != nil)
					[newSubscribers addObject:subsName];
			}
		}
		
		self.subscribers = [NSArray arrayWithArray:newSubscribers];
		sp_playlist_subscribers_free(subs);
		
	} else if (self.subscribers != nil) {
		self.subscribers = nil;
	}	
}

-(void)rebuildItems {
	
    NSUInteger itemCount = sp_playlist_num_tracks(playlist);
    NSMutableArray *newItems = [NSMutableArray arrayWithCapacity:itemCount];
    
    NSUInteger currentItemIndex = 0;
    for (currentItemIndex = 0; currentItemIndex < itemCount; currentItemIndex++) {
        
        sp_track *trackStruct = sp_playlist_track(playlist, (int)currentItemIndex);
        
        if (trackStruct != NULL) {
			[newItems addObject:[[[SPPlaylistItem alloc] initWithPlaceholderTrack:trackStruct
																		  atIndex:(int)currentItemIndex
																	   inPlaylist:self] autorelease]];
        }
    }
	
	NSMutableArray *itemContainer = self.items;
	if ([newItems isEqualToArray:itemContainer])
		return;
	
	self.trackChangesAreFromLibSpotifyCallback = YES;
	
	[self willChangeValueForKey:@"items"];
	[itemWrapper release];
	itemWrapper = [newItems mutableCopy];
	[self didChangeValueForKey:@"items"];
	
	self.trackChangesAreFromLibSpotifyCallback = NO;
}

-(void)resetItemIndexes {
	NSUInteger itemCount = [itemWrapper count];
	for (NSUInteger currentItemIndex = 0; currentItemIndex < itemCount; currentItemIndex++)
		[(SPPlaylistItem *)[itemWrapper objectAtIndex:currentItemIndex] setItemIndexFromLibSpotify:(int)currentItemIndex];
}

-(BOOL)moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)newLocation error:(NSError **)error {
	
	int count = (int)[indexes count];
	int indexArray[count];
	
	NSUInteger index = [indexes firstIndex];
	for (NSUInteger i = 0; i < [indexes count]; i++) {
		indexArray[i] = (int)index;
		index = [indexes indexGreaterThanIndex:index];
	}
	
	const int *indexArrayPtr = (const int *)&indexArray;
	sp_error errorCode = sp_playlist_reorder_tracks(playlist, indexArrayPtr, count, (int)newLocation);
	
	if (errorCode != SP_ERROR_OK && error != nil) {
		*error = [NSError spotifyErrorWithCode:errorCode];
	}
	
	return errorCode == SP_ERROR_OK;
}

#pragma mark -

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
	if (sel == @selector(items)) {
		return [super methodSignatureForSelector:@selector(mutableArrayValueForKey:)];
	} else {
		return [super methodSignatureForSelector:sel];
	}
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	
	if ([invocation selector] == @selector(items)) {
		id value = [self mutableArrayValueForKey:@"items"];
		[invocation setReturnValue:&value];
	}
}

#pragma mark -
#pragma mark Mutable Array KVC

-(NSInteger)countOfItems {
	return [itemWrapper count];
}

-(SPPlaylistItem *)objectInItemsAtIndex:(NSInteger)anIndex {
	return [itemWrapper objectAtIndex:anIndex];
}

-(void)insertObject:(id)anItem inItemsAtIndex:(NSInteger)anIndex {
	if (anItem != nil) {
		if (self.trackChangesAreFromLibSpotifyCallback) {
			[itemWrapper insertObject:anItem atIndex:anIndex];
			[self resetItemIndexes];
			
		} else if (([anItem isKindOfClass:[SPTrack class]]) || ([anItem isKindOfClass:[SPPlaylistItem class]] && ((SPPlaylistItem *)anItem).itemClass == [SPTrack class])) {
			
			sp_track *track;
			
			if ([anItem isKindOfClass:[SPTrack class]])
				track = [anItem track];
			else
				track = [(SPTrack *)((SPPlaylistItem *)anItem).item track];
			
			sp_track *const *trackPointer = &track;
			sp_playlist_add_tracks(playlist, trackPointer, 1, (int)anIndex, [session session]);
		}
	}
}

-(void)removeObjectFromItemsAtIndex:(NSInteger)anIndex {
	if (self.trackChangesAreFromLibSpotifyCallback) {
		[itemWrapper removeObjectAtIndex:anIndex];
		[self resetItemIndexes];
	} else {
		int intIndex = (int)anIndex; 
		const int *indexPtr = &intIndex;
		sp_playlist_remove_tracks(playlist, indexPtr, 1);
	}
}

-(void)removeItemsAtIndexes:(NSIndexSet *)indexes {
	if (self.trackChangesAreFromLibSpotifyCallback) {
		[itemWrapper removeObjectsAtIndexes:indexes];
		[self resetItemIndexes];
	} else {
		int count = (int)[indexes count];
		int indexArray[count];
		
		NSUInteger index = [indexes firstIndex];
		for (NSUInteger i = 0; i < [indexes count]; i++) {
			indexArray[i] = (int)index;
			index = [indexes indexGreaterThanIndex:index];
		}
		
		const int *indexArrayPtr = (const int *)&indexArray;
		sp_playlist_remove_tracks(playlist, indexArrayPtr, count);
	}
}

-(void)dealloc {
    
    [self removeObserver:self forKeyPath:@"name"];
    [self removeObserver:self forKeyPath:@"playlistDescription"];
    [self removeObserver:self forKeyPath:@"collaborative"];
    [self removeObserver:self forKeyPath:@"loaded"];
    
	
	self.subscribers = nil;
    [self setName:nil];
    [self setPlaylistDescription:nil];
    [self setDelegate:nil];
    [self setOwner:nil];
	[self setItemWrapper:nil];
    
    session = nil;
    
	if (playlist != NULL) {
		sp_playlist_remove_callbacks(playlist, &_playlistCallbacks, (void *)self);
		sp_playlist_release(playlist);
    }
		
    [super dealloc];
}


@end
