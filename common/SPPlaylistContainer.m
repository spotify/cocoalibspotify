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

@interface SPPlaylistContainer ()

-(void)rebuildPlaylists;
@property (nonatomic, readwrite, retain) SPUser *owner;
@property (nonatomic, readwrite, retain) SPPlaylistFolder *rootFolder;
@property (nonatomic, readwrite, assign) __weak SPSession *session;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;

@end

static void playlist_added(sp_playlistcontainer *pc, sp_playlist *playlist, int position, void *userdata) {
	// Find the object model container, add the playlist to it
	return;
	if (sp_playlistcontainer_playlist_type(pc, position) == SP_PLAYLIST_TYPE_END_FOLDER)
		return; // We'll deal with this when the folder itself is added 
}


static void playlist_removed(sp_playlistcontainer *pc, sp_playlist *playlist, int position, void *userdata) {
	// Find the object model container, remove the playlist from it
	return;
	if (sp_playlistcontainer_playlist_type(pc, position) == SP_PLAYLIST_TYPE_END_FOLDER)
		return; // We'll deal with this when the folder itself is removed 
}

static void playlist_moved(sp_playlistcontainer *pc, sp_playlist *playlist, int position, int new_position, void *userdata) {
	// Find the old and new containers. If they're the same, move, otherwise remove from old and add to new
}


static void container_loaded(sp_playlistcontainer *pc, void *userdata) {
	SPPlaylistContainer *container = userdata;
	container.loaded = YES;
	[container rebuildPlaylists];
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
@synthesize container;
@synthesize rootFolder;
@synthesize loaded;

-(void)rebuildPlaylists {
	self.owner = [SPUser userWithUserStruct:sp_playlistcontainer_owner(container) inSession:session];
	[self.rootFolder rangeMayHaveChanged]; 
}

+(NSSet *)keyPathsForValuesAffectingPlaylists {
	return [NSSet setWithObject:@"rootFolder.playlists"];
}

-(NSMutableArray *)playlists {
	return [self.rootFolder mutableArrayValueForKey:@"playlists"];
}

#pragma mark -

-(SPPlaylist *)createPlaylistWithName:(NSString *)name {
	
	if ([[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0 ||
		[name length] > 255)
		return nil;
	
	sp_playlist *newPlaylist = sp_playlistcontainer_add_new_playlist(self.container, [name UTF8String]);
	
	if (newPlaylist != NULL)
		return [SPPlaylist playlistWithPlaylistStruct:newPlaylist inSession:self.session];
	else
		return nil;
}

-(SPPlaylistFolder *)createFolderWithName:(NSString *)name error:(NSError **)error {
	
	sp_error errorCode = sp_playlistcontainer_add_folder(self.container, 0, [name UTF8String]);
	
	if (errorCode != SP_ERROR_OK)
		return [[[SPPlaylistFolder alloc] initWithPlaylistFolderId:sp_playlistcontainer_playlist_folder_id(self.container, 0)
												container:self
												inSession:self.session] autorelease];
	else if (error != NULL)
		*error = [NSError spotifyErrorWithCode:errorCode];
	
	return nil;
}

-(BOOL)movePlaylistOrFolderAtIndex:(NSUInteger)aVirtualPlaylistOrFolderIndex
						  ofParent:(SPPlaylistFolder *)existingParentFolderOrNil
						   toIndex:(NSUInteger)newVirtualIndex 
					   ofNewParent:(SPPlaylistFolder *)aParentFolderOrNil
							 error:(NSError **)err {
	
	SPPlaylistFolder *oldParentFolder = (existingParentFolderOrNil == nil || (id)existingParentFolderOrNil == self) ? rootFolder : existingParentFolderOrNil;
	SPPlaylistFolder *newParentFolder = (aParentFolderOrNil == nil || (id)aParentFolderOrNil == nil) ? rootFolder : aParentFolderOrNil;
	NSUInteger oldFlattenedIndex = [oldParentFolder flattenedIndexForVirtualChildIndex:aVirtualPlaylistOrFolderIndex];
	NSUInteger newFlattenedIndex = [newParentFolder flattenedIndexForVirtualChildIndex:newVirtualIndex];
	sp_playlist_type playlistType = sp_playlistcontainer_playlist_type(container, (int)oldFlattenedIndex);
	
	if (playlistType == SP_PLAYLIST_TYPE_PLAYLIST) {
		
		sp_error errorCode = sp_playlistcontainer_move_playlist(container, (int)oldFlattenedIndex, (int)newFlattenedIndex, false);
		
		if (errorCode != SP_ERROR_OK) {
			if (err != NULL)
				*err = [NSError spotifyErrorWithCode:errorCode];
			return NO;
		}
		
		return YES;
		
	} else if (playlistType == SP_PLAYLIST_TYPE_START_FOLDER) {
		
		SPPlaylistFolder *folderToMove = [self.session playlistFolderForFolderId:sp_playlistcontainer_playlist_folder_id(container, (int)oldFlattenedIndex)
																	 inContainer:self];
		NSUInteger targetIndex = newFlattenedIndex;
		NSUInteger sourceIndex = oldFlattenedIndex;
		
		sp_playlistcontainer_remove_callbacks(container, &playlistcontainer_callbacks, self);
		
		for (NSUInteger entriesToMove = folderToMove.containerPlaylistRange.length; entriesToMove > 0; entriesToMove--) {
			
			sp_error errorCode = sp_playlistcontainer_move_playlist(container, (int)sourceIndex, (int)targetIndex, false);
			
			if (errorCode != SP_ERROR_OK) {
				if (err != NULL)
					*err = [NSError spotifyErrorWithCode:errorCode];
				return NO;
			}
			
			if (targetIndex < sourceIndex) {
				targetIndex++;
				sourceIndex++;
			}
		}
		
		sp_playlistcontainer_add_callbacks(container, &playlistcontainer_callbacks, self);
		if (sp_playlistcontainer_is_loaded(container))
			container_loaded(container, self);
		
		return YES;
	}
	return NO;
}

-(void)dealloc {
    
    self.session = nil;
	self.rootFolder = nil;
	self.owner = nil;
    
    sp_playlistcontainer_remove_callbacks(container, &playlistcontainer_callbacks, self);
    sp_playlistcontainer_release(container);
    
    [super dealloc];
}

@end

@implementation SPPlaylistContainer (SPPlaylistContainerInternal)

-(id)initWithContainerStruct:(sp_playlistcontainer *)aContainer inSession:(SPSession *)aSession {
    
    if ((self = [super init])) {
        container = aContainer;
        sp_playlistcontainer_add_ref(container);
        self.session = aSession;
		
		self.rootFolder = [[[SPPlaylistFolder alloc] initWithPlaylistFolderId:0 container:self inSession:self.session] autorelease];
		[self rebuildPlaylists];
        
        sp_playlistcontainer_add_callbacks(container, &playlistcontainer_callbacks, self);
    }
    return self;
}

-(void)removeFolderFromTree:(SPPlaylistFolder *)aFolder {
	
	// Remove callbacks, since we have to remove two playlists and reacting to list change notifications halfway through would be bad.
	sp_playlistcontainer_remove_callbacks(container, &playlistcontainer_callbacks, self);
	
	NSUInteger folderIndex = aFolder.containerPlaylistRange.location;
	NSUInteger entriesToRemove = aFolder.containerPlaylistRange.length;
	
	while (entriesToRemove > 0) {
		sp_playlistcontainer_remove_playlist(container, (int)folderIndex);
		entriesToRemove--;
	}
	
	sp_playlistcontainer_add_callbacks(container, &playlistcontainer_callbacks, self);
}

@end

