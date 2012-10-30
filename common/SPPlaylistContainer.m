//
//  SPPlaylistContainer.m
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

#import "SPPlaylistContainer.h"
#import "SPPlaylistFolder.h"
#import "SPUser.h"
#import "SPSession.h"
#import "SPPlaylist.h"
#import "SPErrorExtensions.h"
#import "SPPlaylistContainerInternal.h"
#import "SPPlaylistFolderInternal.h"

@interface SPPlaylistContainerCallbackProxy : NSObject
// SPPlaylistContainerCallbackProxy is here to bridge the gap between -dealloc and the 
// playlist callbacks being unregistered, since that's done async.
@property (nonatomic, readwrite, assign) __unsafe_unretained SPPlaylistContainer *container;
@end

@implementation SPPlaylistContainerCallbackProxy
@synthesize container;
@end


@interface SPPlaylistContainer ()

-(NSArray *)createPlaylistTree;

@property (nonatomic, readwrite, strong) SPUser *owner;
@property (nonatomic, readwrite, assign) __unsafe_unretained SPSession *session;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite, strong) NSArray *playlists;
@property (nonatomic, readwrite, strong) NSMutableDictionary *folderCache;
@property (nonatomic, readwrite, strong) SPPlaylistContainerCallbackProxy *callbackProxy;

@property (nonatomic, readwrite, strong) NSMutableArray *playlistAddCallbackStack;
@property (nonatomic, readwrite, strong) NSMutableArray *playlistRemoveCallbackStack;

@property (nonatomic, readwrite) sp_playlistcontainer *container;

-(NSRange)rangeOfFolderInRootList:(SPPlaylistFolder *)folder;
-(NSInteger)indexInFlattenedListForIndex:(NSUInteger)virtualIndex inFolder:(SPPlaylistFolder *)parentFolder;
-(void)removeFolderFromTree:(SPPlaylistFolder *)aPlaylistOrFolderIndex callback:(SPErrorableOperationCallback)block;
-(void)removePlaylist:(SPPlaylist *)aPlaylist callback:(SPErrorableOperationCallback)block;
-(NSArray *)playlistsInFolder:(SPPlaylistFolder *)folder;

@end

static void playlist_added(sp_playlistcontainer *pc, sp_playlist *playlist, int position, void *userdata) {
	// Find the object model container, add the playlist to it
	
	SPPlaylistContainerCallbackProxy *proxy = (__bridge SPPlaylistContainerCallbackProxy *)userdata;
	SPPlaylistContainer *container = proxy.container;
	if (!container) return;
	
	NSArray *newTree = [container createPlaylistTree];
	SPPlaylist *newPlaylist = [SPPlaylist playlistWithPlaylistStruct:playlist inSession:container.session];
	
	void (^callback)(SPPlaylist *) = nil;
	if (container.playlistAddCallbackStack.count > 0) {
		callback = [container.playlistAddCallbackStack objectAtIndex:0];
		[container.playlistAddCallbackStack removeObjectAtIndex:0];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^() {
		container.playlists = newTree;
		if (callback) callback(newPlaylist);
	});
}


static void playlist_removed(sp_playlistcontainer *pc, sp_playlist *playlist, int position, void *userdata) {
	
	SPPlaylistContainerCallbackProxy *proxy = (__bridge SPPlaylistContainerCallbackProxy *)userdata;
	SPPlaylistContainer *container = proxy.container;
	if (!container) return;
	
	NSArray *newTree = [container createPlaylistTree];
	SPErrorableOperationCallback callback = nil;
	
	if (container.playlistRemoveCallbackStack.count > 0) {
		callback = [container.playlistRemoveCallbackStack objectAtIndex:0];
		[container.playlistRemoveCallbackStack removeObjectAtIndex:0];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^() {
		container.playlists = newTree;
		if (callback) callback(nil);
	});
}

static void playlist_moved(sp_playlistcontainer *pc, sp_playlist *playlist, int position, int new_position, void *userdata) {
	// Find the old and new containers. If they're the same, move, otherwise remove from old and add to new
}


static void container_loaded(sp_playlistcontainer *pc, void *userdata) {
		
	SPPlaylistContainerCallbackProxy *proxy = (__bridge SPPlaylistContainerCallbackProxy *)userdata;
	SPPlaylistContainer *container = proxy.container;
	if (!container) return;
	
	SPUser *user = [SPUser userWithUserStruct:sp_playlistcontainer_owner(container.container) inSession:container.session];
	NSArray *newTree = [container createPlaylistTree];
	
	dispatch_async(dispatch_get_main_queue(), ^() {
		container.owner = user;
		container.playlists = newTree;
		container.loaded = YES;
	});
}

static sp_playlistcontainer_callbacks playlistcontainer_callbacks = {
	&playlist_added,
	&playlist_removed,
	&playlist_moved,
	&container_loaded
};

#pragma mark -

@implementation SPPlaylistContainer

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], [self playlists]];
}

@synthesize owner;
@synthesize session;
@synthesize container = _container;
@synthesize loaded;
@synthesize folderCache;
@synthesize playlists;
@synthesize callbackProxy;
@synthesize playlistAddCallbackStack;
@synthesize playlistRemoveCallbackStack;

-(sp_playlistcontainer *)container {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif 
	return _container;
}

-(void)startLoading {
	
	dispatch_libspotify_async(^{
		
		if (self.callbackProxy != nil) return;
		
		self.callbackProxy = [[SPPlaylistContainerCallbackProxy alloc] init];
		self.callbackProxy.container = self;
		
        sp_playlistcontainer_add_callbacks(self.container, &playlistcontainer_callbacks, (__bridge void *)(self.callbackProxy));
		
		NSArray *newTree = [self createPlaylistTree];
		SPUser *user = nil;
		BOOL isLoaded = sp_playlistcontainer_is_loaded(self.container);
		
		if (isLoaded)
			user = [SPUser userWithUserStruct:sp_playlistcontainer_owner(self.container) inSession:self.session];
		
		dispatch_async(dispatch_get_main_queue(), ^() {
			self.owner = user;
			self.playlists = newTree;
			self.loaded = isLoaded;
		});
	});
}

-(NSArray *)createPlaylistTree {
	
	SPAssertOnLibSpotifyThread();
	
	NSInteger itemCount = sp_playlistcontainer_num_playlists(self.container);
	
	if (itemCount == -1) return nil;
	
	NSMutableArray *rootPlaylistList = [NSMutableArray arrayWithCapacity:itemCount];
	SPPlaylistFolder *folderAtTopOfStack = nil;
	
	for (int currentItem = 0; currentItem < itemCount; currentItem++) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(self.container, currentItem);
		
		if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			SPPlaylistFolder *folder = [self.session playlistFolderForFolderId:folderId inContainer:self];
			[folder clearAllItems];
			
			char nameChars[256];
			sp_error nameError = sp_playlistcontainer_playlist_folder_name(self.container, currentItem, nameChars, sizeof(nameChars));
			if (nameError == SP_ERROR_OK)
				folder.name = [NSString stringWithUTF8String:nameChars];
			
			if (folderAtTopOfStack) {
				[folderAtTopOfStack addObject:folder];
				folder.parentFolder = folderAtTopOfStack;
			} else {
				[rootPlaylistList addObject:folder];
				folder.parentFolder = nil;
			}
			
			folderAtTopOfStack = folder;
			
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			
			if (folderAtTopOfStack.folderId != folderId)
				NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"WARNING: Root list is insane!");
			
			folderAtTopOfStack = folderAtTopOfStack.parentFolder;
			
		} else if (type == SP_PLAYLIST_TYPE_PLAYLIST) {
			
			SPPlaylist *playlist = [SPPlaylist playlistWithPlaylistStruct:sp_playlistcontainer_playlist(self.container, currentItem)
																inSession:self.session];
			
			if (folderAtTopOfStack)
				[folderAtTopOfStack addObject:playlist];
			else
				[rootPlaylistList addObject:playlist];
			
		} else if (type == SP_PLAYLIST_TYPE_PLACEHOLDER) {
			SPUnknownPlaylist *playlist = [self.session unknownPlaylistForPlaylistStruct:sp_playlistcontainer_playlist(self.container, currentItem)];
			
			if (folderAtTopOfStack)
				[folderAtTopOfStack addObject:playlist];
			else
				[rootPlaylistList addObject:playlist];
		}
	}
	
	return [NSArray arrayWithArray:rootPlaylistList];
}


-(NSInteger)indexInFlattenedListForIndex:(NSUInteger)virtualIndex inFolder:(SPPlaylistFolder *)parentFolder {
	
	SPAssertOnLibSpotifyThread();
	
	NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:self.playlists.count];
	NSRange folderRangeInRootList = [self rangeOfFolderInRootList:parentFolder];
	
	if (folderRangeInRootList.location == NSNotFound) return NSNotFound;
	
	NSRange rangeOfPlaylists = parentFolder == nil ? folderRangeInRootList : NSMakeRange(folderRangeInRootList.location + 1, folderRangeInRootList.length - 2);
	NSUInteger currentRootlistIndex = rangeOfPlaylists.location;
	
	NSArray *playlistsOfParent = parentFolder == nil ? self.playlists : parentFolder.playlists;
	
	for (NSUInteger currentIndex = 0; currentIndex < playlistsOfParent.count; currentIndex++) {
		// For each index in our items, we want the rootlist index that'd replace it.
		
		[indexes addObject:[NSNumber numberWithInteger:currentRootlistIndex]];
		
		id item = [playlistsOfParent objectAtIndex:currentIndex];
		
		if ([item isKindOfClass:[SPPlaylist class]])
			currentRootlistIndex++;
		else if ([item isKindOfClass:[SPPlaylistFolder class]])
			currentRootlistIndex += [self rangeOfFolderInRootList:item].length;
	}
	
	// The indexes array now contains the root list index for the item at the virtual index
	if (virtualIndex == playlistsOfParent.count)
		return rangeOfPlaylists.location + rangeOfPlaylists.length; // Why did we just do that loop?
	else if (virtualIndex > playlistsOfParent.count)
		return NSNotFound;
	else
		return [[indexes objectAtIndex:virtualIndex] integerValue];
}

-(NSInteger)virtualIndexForFlattenedIndex:(NSUInteger)flattenedIndex parentFolder:(SPPlaylistFolder **)parent {
	return NSNotFound;
}

-(NSRange)rangeOfFolderInRootList:(SPPlaylistFolder *)folder {
	
	SPAssertOnLibSpotifyThread();
	
	if (!folder) return NSMakeRange(0, sp_playlistcontainer_num_playlists(self.container));
	
	NSRange folderRange = NSMakeRange(NSNotFound, 0);
	NSInteger itemCount = sp_playlistcontainer_num_playlists(self.container);
	
	for (int currentItem = 0; currentItem < itemCount; currentItem++) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(self.container, currentItem);
		
		if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			if (folderId == folder.folderId)
				folderRange.location = currentItem;
			
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			if (folderId == folder.folderId) {
				folderRange.length = (currentItem - folderRange.location) + 1;
				if (folderRange.location == NSNotFound)
					NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"WARNING: Root list is insane!");
			}
		}
	}
	
	return folderRange;
}

#pragma mark -

-(NSArray *)flattenedPlaylists {
	
	NSArray *tree = [self.playlists copy];
	NSMutableArray *flatList = [NSMutableArray array];
	
	for (id item in tree) {
		if ([item isKindOfClass:[SPPlaylist class]])
			[flatList addObject:item];
		else if ([item isKindOfClass:[SPPlaylistFolder class]])
			[flatList addObjectsFromArray:[self playlistsInFolder:item]];
	}
	
	return [NSArray arrayWithArray:flatList];
}

-(NSArray *)playlistsInFolder:(SPPlaylistFolder *)folder {
	
	NSMutableArray *playlistsInFolder = [NSMutableArray array];
	
	for (id item in folder.playlists) {
		
		if ([item isKindOfClass:[SPPlaylist class]])
			[playlistsInFolder addObject:item];
		else if ([item isKindOfClass:[SPPlaylistFolder class]])
			[playlistsInFolder addObjectsFromArray:[self playlistsInFolder:item]];
	}
	
	return [NSArray arrayWithArray:playlistsInFolder];
}

-(void)createPlaylistWithName:(NSString *)name callback:(void (^)(SPPlaylist *))block {
	
	dispatch_libspotify_async(^{
		
		if ([[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0 ||
			[name length] > 255) {
			dispatch_async(dispatch_get_main_queue(), ^() { if (block) block(nil); });
			return;
		}
		
		if (block)
			[self.playlistAddCallbackStack addObject:block];
			
		sp_playlist *newPlaylist = sp_playlistcontainer_add_new_playlist(self.container, [name UTF8String]);
		if (newPlaylist == NULL && block) {
			[self.playlistAddCallbackStack removeObject:block];
			dispatch_async(dispatch_get_main_queue(), ^{ block(nil); });
		}
	});
}

-(void)createFolderWithName:(NSString *)name callback:(void (^)(SPPlaylistFolder *, NSError *))block {
	
	dispatch_libspotify_async(^{
		
		sp_error errorCode = sp_playlistcontainer_add_folder(self.container, 0, [name UTF8String]);
		
		NSError *error = nil;
		SPPlaylistFolder *folder = nil;
		
		if (errorCode == SP_ERROR_OK)
			folder = [[SPPlaylistFolder alloc] initWithPlaylistFolderId:sp_playlistcontainer_playlist_folder_id(self.container, 0)
															  container:self
															  inSession:self.session];
		else if (error != NULL)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^() { if (block) block(folder, error); });
		
	});
}

-(void)removeItem:(id)playlistOrFolder callback:(SPErrorableOperationCallback)block {
	
	if ([playlistOrFolder isKindOfClass:[SPPlaylistFolder class]])
		[self removeFolderFromTree:playlistOrFolder callback:block];
	else if ([playlistOrFolder isKindOfClass:[SPPlaylist class]])
		[self removePlaylist:playlistOrFolder callback:block];
	else if (block)
		block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]);
	
}

-(void)removePlaylist:(SPPlaylist *)aPlaylist callback:(SPErrorableOperationCallback)block {
	
	if (aPlaylist == nil)
		if (block) dispatch_async(dispatch_get_main_queue(), ^{ block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]); });
	
	dispatch_libspotify_async(^{
		
		NSUInteger playlistCount = sp_playlistcontainer_num_playlists(self.container);
		
		if (block)
			[self.playlistRemoveCallbackStack addObject:block];
		
		NSError *error = [NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA];
		
		for (int currentIndex = 0; currentIndex < playlistCount; currentIndex++) {
			sp_playlist *playlist = sp_playlistcontainer_playlist(self.container, currentIndex);
			if (playlist == aPlaylist.playlist) {
				sp_error errorCode = sp_playlistcontainer_remove_playlist(self.container, currentIndex);
				if (errorCode != SP_ERROR_OK)
					error = [NSError spotifyErrorWithCode:errorCode];
				else
					error = nil;
				break;
			}
		}
		
		if (error) {
			[self.playlistRemoveCallbackStack removeObject:block];
			dispatch_async(dispatch_get_main_queue(), ^{ block(error); });
		}
	});
}

-(void)removeFolderFromTree:(SPPlaylistFolder *)aFolder callback:(SPErrorableOperationCallback)block {
	
	if (aFolder == nil)
		if (block) dispatch_async(dispatch_get_main_queue(), ^{ block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]); });
	
	dispatch_libspotify_async(^{
		
		// Remove callbacks, since we have to remove two playlists and reacting to list change notifications halfway through would be bad.
		self.callbackProxy.container = nil;
		sp_playlistcontainer_remove_callbacks(self.container, &playlistcontainer_callbacks, (__bridge void *)(self.callbackProxy));
		self.callbackProxy = nil;
		
		
		NSRange folderRange = [self rangeOfFolderInRootList:aFolder];
		NSUInteger entriesToRemove = folderRange.length;
		
		while (entriesToRemove > 0) {
			sp_playlistcontainer_remove_playlist(self.container, (int)folderRange.location);
			entriesToRemove--;
		}
		
		self.callbackProxy = [[SPPlaylistContainerCallbackProxy alloc] init];
		self.callbackProxy.container = self;
		sp_playlistcontainer_add_callbacks(self.container, &playlistcontainer_callbacks, (__bridge void *)(self.callbackProxy));
		
		NSArray *newTree = [self createPlaylistTree];
		dispatch_async(dispatch_get_main_queue(), ^{
			self.playlists = newTree;
			if (block) block(nil);
		});
	});
}

-(void)moveItem:(id)playlistOrFolder
		toIndex:(NSUInteger)newIndex 
	ofNewParent:(SPPlaylistFolder *)aParentFolderOrNil
	   callback:(SPErrorableOperationCallback)block {
	
	if ([playlistOrFolder isKindOfClass:[SPPlaylist class]]) {
		
		dispatch_libspotify_async(^{
			
			NSInteger sourceIndex = NSNotFound;
			SPPlaylist *sourcePlaylist = playlistOrFolder;
			
			NSUInteger playlistCount = sp_playlistcontainer_num_playlists(self.container);
			
			for (int currentIndex = 0; currentIndex < playlistCount; currentIndex++) {
				sp_playlist *playlist = sp_playlistcontainer_playlist(self.container, currentIndex);
				if (playlist == sourcePlaylist.playlist) {
					sourceIndex = currentIndex;
					break;
				}
			}
			
			if (sourceIndex == NSNotFound) {
				dispatch_async(dispatch_get_main_queue(), ^{ if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]); });
				return;
			}
			
			NSInteger destinationIndex = [self indexInFlattenedListForIndex:newIndex inFolder:aParentFolderOrNil];
			
			if (destinationIndex == NSNotFound) {
				dispatch_async(dispatch_get_main_queue(), ^{ if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INDEX_OUT_OF_RANGE]); });
				return;
			}
			
			sp_error errorCode = sp_playlistcontainer_move_playlist(self.container, (int)sourceIndex, (int)destinationIndex, false);
			
			if (errorCode != SP_ERROR_OK)
				dispatch_async(dispatch_get_main_queue(), ^{ if (block) block([NSError spotifyErrorWithCode:errorCode]); });
			else if (block)
				dispatch_async(dispatch_get_main_queue(), ^{ block(nil); });
		});
		
		
		
	} else if ([playlistOrFolder isKindOfClass:[SPPlaylistFolder class]]) {
		
		dispatch_libspotify_async(^{
			
			self.callbackProxy.container = nil;
			sp_playlistcontainer_remove_callbacks(self.container, &playlistcontainer_callbacks, (__bridge void *)(self.callbackProxy));
			self.callbackProxy = nil;
			
			NSInteger sourceIndex = NSNotFound;
			SPPlaylistFolder *folder = playlistOrFolder;
			NSRange folderRange = [self rangeOfFolderInRootList:folder];
			sourceIndex = folderRange.location;
			
			if (sourceIndex == NSNotFound) {
				dispatch_async(dispatch_get_main_queue(), ^{ if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]); });
				return;
			}
			
			NSInteger destinationIndex = [self indexInFlattenedListForIndex:newIndex inFolder:aParentFolderOrNil];
			
			if (destinationIndex == NSNotFound) {
				dispatch_async(dispatch_get_main_queue(), ^{ if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INDEX_OUT_OF_RANGE]); });
				return;
			}
			
			for (NSUInteger entriesToMove = folderRange.length; entriesToMove > 0; entriesToMove--) {
				
				sp_error errorCode = sp_playlistcontainer_move_playlist(self.container, (int)sourceIndex, (int)destinationIndex, false);
				NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
				
				if (error) {
					dispatch_async(dispatch_get_main_queue(), ^() { if (block) block(error); });
					return;
				}
				
				if (destinationIndex < sourceIndex) {
					destinationIndex++;
					sourceIndex++;
				}
			}
			
			self.callbackProxy = [[SPPlaylistContainerCallbackProxy alloc] init];
			self.callbackProxy.container = self;
			sp_playlistcontainer_add_callbacks(self.container, &playlistcontainer_callbacks, (__bridge void *)(self.callbackProxy));
			if (sp_playlistcontainer_is_loaded(self.container))
				container_loaded(self.container, (__bridge void *)(self.callbackProxy));
			
			dispatch_async(dispatch_get_main_queue(), ^() { if (block) block(nil); });
			
		});
		
	} else if (block) {
		block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]);
	}
}

-(void)subscribeToPlaylist:(SPPlaylist *)playlist callback:(SPErrorableOperationCallback)block {

	if (playlist == nil ||
		playlist.owner == self.session.user ||
		[self.flattenedPlaylists containsObject:playlist]) {

		if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]);
		return;
	}

	dispatch_libspotify_async(^{

		sp_link *link = sp_link_create_from_playlist(playlist.playlist);
		sp_playlist *subbedPlaylist = sp_playlistcontainer_add_playlist(self.container, link);
		sp_link_release(link);
		link = NULL;

			if (block)
				dispatch_async(dispatch_get_main_queue(), ^{
					NSError *error = nil;
					if (subbedPlaylist == NULL)
						error = [NSError spotifyErrorWithCode:SP_ERROR_OTHER_PERMANENT];

					block(error);
				});
	});
}

-(void)dealloc {
    
    self.session = nil;
    
	sp_playlistcontainer *outgoing_container = _container;
	SPPlaylistContainerCallbackProxy *outgoingProxy = self.callbackProxy;
	self.callbackProxy.container = nil;
	self.callbackProxy = nil;
	
    dispatch_libspotify_async(^() {
		if (outgoing_container) sp_playlistcontainer_remove_callbacks(outgoing_container, &playlistcontainer_callbacks, (__bridge void *)outgoingProxy);
		if (outgoing_container) sp_playlistcontainer_release(outgoing_container);
    });
}

@end

@implementation SPPlaylistContainer (SPPlaylistContainerInternal)

-(id)initWithContainerStruct:(sp_playlistcontainer *)aContainer inSession:(SPSession *)aSession {
    
	SPAssertOnLibSpotifyThread();
	
    if ((self = [super init])) {
        self.container = aContainer;
        sp_playlistcontainer_add_ref(self.container);
        self.session = aSession;
		self.playlistAddCallbackStack = [NSMutableArray new];
		self.playlistRemoveCallbackStack = [NSMutableArray new];
		
		if (self.session.loadingPolicy == SPAsyncLoadingImmediate)
			dispatch_async(dispatch_get_main_queue(), ^() { [self startLoading]; });
    }
    return self;
}

-(void)printRootList {
	
	SPAssertOnLibSpotifyThread();
	
	NSInteger itemCount = sp_playlistcontainer_num_playlists(self.container);
	if (itemCount == -1) {
		NSLog(@"Item count of container is -1.");
		return;
	}
	
	for (int currentItem = 0; currentItem < itemCount; currentItem++) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(self.container, currentItem);
		
		if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			
			char nameChars[256];
			NSString *folderName = nil;
			sp_error nameError = sp_playlistcontainer_playlist_folder_name(self.container, currentItem, nameChars, sizeof(nameChars));
			if (nameError == SP_ERROR_OK)
				folderName = [NSString stringWithUTF8String:nameChars];
			
			NSLog(@"%u: ---- Folder Start Marker: %llu ---- (%@)", currentItem, folderId, folderName);
			
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			
			sp_uint64 folderId = sp_playlistcontainer_playlist_folder_id(self.container, currentItem);
			NSLog(@"%u: ---- Folder End Marker: %llu ----", currentItem, folderId);
			
		} else if (type == SP_PLAYLIST_TYPE_PLAYLIST) {
			
			sp_playlist *pl = sp_playlistcontainer_playlist(self.container, currentItem);
			NSString *playlistName = [NSString stringWithUTF8String:sp_playlist_name(pl)];
			
			sp_link *link = sp_link_create_from_playlist(pl);
			char uriChars[256];
			sp_link_as_string(link, (char *)&uriChars, sizeof(uriChars));
			
			NSString *playlistUrl = [NSString stringWithUTF8String:uriChars];
			free(link);
			link = NULL;
			
			NSLog(@"%u: Playlist: %@ (%@)", currentItem, playlistUrl, playlistName);
			
		} else if (type == SP_PLAYLIST_TYPE_PLACEHOLDER) {
			NSLog(@"%u: Placeholder Playlist", currentItem);
		}
	}
	
}

@end

