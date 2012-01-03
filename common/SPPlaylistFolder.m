//
//  SPPlaylistFolder.m
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

/*
 In a very Matrix-y fashion, There Is No SPPlaylistFolder. Instead, SPPlaylistFolder is just a pointer to
 a range of playlists in its parent SPPlaylistContainer. 
 */

#import "SPPlaylistFolder.h"
#import "SPPlaylistContainer.h"
#import "SPSession.h"
#import "CocoaLibSpotifyPlatformImports.h"
#import "SPPlaylistContainerInternal.h"
#import "SPPlaylistFolderInternal.h"

@interface SPPlaylistFolder ()

@property (nonatomic, readwrite, assign) __weak SPPlaylistContainer *parentContainer;
@property (readwrite, nonatomic, copy) NSString *name;
@property (nonatomic, readwrite, assign) __weak SPSession *session;

-(void)performIntegrityCheck;
-(NSRange)rangeOfChildObjects;

@end

@implementation SPPlaylistFolder

@synthesize parentContainer;
@dynamic playlists;
@synthesize name;
@synthesize session;
@synthesize folderId;

-(void)performIntegrityCheck {
	
	if (folderId == 0)
		return; // We're a special folder!
	
	sp_playlist_type firstItemType = sp_playlistcontainer_playlist_type(self.parentContainer.container, (int)self.containerPlaylistRange.location);
	sp_playlist_type lastItemType = sp_playlistcontainer_playlist_type(self.parentContainer.container, (int)(self.containerPlaylistRange.location + (self.containerPlaylistRange.length - 1)));
	
	NSAssert(firstItemType == SP_PLAYLIST_TYPE_START_FOLDER, @"Integrity check: First item is not SP_PLAYLIST_TYPE_START_FOLDER!");
	NSAssert(lastItemType == SP_PLAYLIST_TYPE_END_FOLDER, @"Integrity check: Last item is not SP_PLAYLIST_TYPE_END_FOLDER!");
	
	sp_uint64 firstItemId = sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, (int)self.containerPlaylistRange.location);
	sp_uint64 lastItemId = sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, (int)(self.containerPlaylistRange.location + (self.containerPlaylistRange.length - 1)));
	
	NSAssert(firstItemId == lastItemId, @"Integrity check: START_FOLDER and END_FOLDER IDs don't match!");
}

-(NSRange)rangeOfChildObjects {
	
	if (self.parentContainer.isLoaded == NO)
		return NSMakeRange(0, 0);
	
	if (folderId == 0) {
		return NSMakeRange(self.containerPlaylistRange.location, self.containerPlaylistRange.length);
	} else {
		return NSMakeRange(self.containerPlaylistRange.location + 1, self.containerPlaylistRange.length - 2);
	}
}

#pragma mark -

-(NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
	if (sel == @selector(playlists)) {
		return [super methodSignatureForSelector:@selector(mutableArrayValueForKey:)];
	} else {
		return [super methodSignatureForSelector:sel];
	}
}

-(void)forwardInvocation:(NSInvocation *)invocation {
	if ([invocation selector] == @selector(playlists)) {
		id value = [self mutableArrayValueForKey:@"playlists"];
		[invocation setReturnValue:&value];
	}
}

+(NSSet *)keyPathsForValuesAffectingPlaylists {
	return [NSSet setWithObjects:@"containerPlaylistRange", @"parentContainer.isLoaded", nil];
}

-(NSInteger)countOfPlaylists {
	
	NSRange children = [self rangeOfChildObjects];
	if (children.length == 0)
		return 0;
	
	NSUInteger lastChildIndex = children.location + (children.length - 1);
	NSUInteger currentIndex = children.location;
	NSUInteger virtualCount = 0;
	NSUInteger folderStackCount = 0;
	
	while (currentIndex <= lastChildIndex) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(parentContainer.container, (int)currentIndex);
		
		if (type == SP_PLAYLIST_TYPE_PLAYLIST && folderStackCount == 0) {
			// Normal playlist, increment as normal if it's not in a folder
			virtualCount++;
		} else if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			// Folder start, increment if it's not in a folder.
			if (folderStackCount == 0)
				virtualCount++;
			folderStackCount++;
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			// Reduce stack count.
			folderStackCount--;
		}
		
		currentIndex++;
	}

	return virtualCount;
}

-(id)objectInPlaylistsAtIndex:(NSInteger)virtualIndex {
	
	int flattenedIndex = (int)[self flattenedIndexForVirtualChildIndex:virtualIndex];
	sp_playlist_type type = sp_playlistcontainer_playlist_type(self.parentContainer.container, flattenedIndex);
	
	if (type == SP_PLAYLIST_TYPE_PLAYLIST) {
		return [self.parentContainer.session playlistForPlaylistStruct:sp_playlistcontainer_playlist(self.parentContainer.container, flattenedIndex)];
	} else if (type == SP_PLAYLIST_TYPE_START_FOLDER || type == SP_PLAYLIST_TYPE_END_FOLDER) {
		return [self.parentContainer.session playlistFolderForFolderId:sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, flattenedIndex)
														   inContainer:self.parentContainer];
	} else {
		[NSException raise:@"Invalid index!" format:@""];
		return nil;
	}
}

-(void)insertObject:(id)aPlaylistOrFolder inPlaylistsAtIndex:(NSInteger)virtualIndex {
	// TODO: This
}

-(void)removeObjectFromPlaylistsAtIndex:(NSInteger)virtualIndex {
	
	NSUInteger flattenedIndex = [self flattenedIndexForVirtualChildIndex:virtualIndex];
	sp_playlist_type type = sp_playlistcontainer_playlist_type(self.parentContainer.container, (int)flattenedIndex);
	
	if (type == SP_PLAYLIST_TYPE_PLAYLIST) {
		sp_playlistcontainer_remove_playlist(self.parentContainer.container, (int)flattenedIndex);
	} else if (type == SP_PLAYLIST_TYPE_START_FOLDER || type == SP_PLAYLIST_TYPE_END_FOLDER) {
		
		sp_uint64 childFolderId = sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, (int)flattenedIndex);
		SPPlaylistFolder *folderToBeRemoved = [self.parentContainer.session playlistFolderForFolderId:childFolderId
																						  inContainer:self.parentContainer]; 
		[self.parentContainer removeFolderFromTree:folderToBeRemoved];
	}
}

#pragma mark -

-(SPPlaylistFolder *)parentFolder {
	
	if (self.containerPlaylistRange.location == 0)
		return nil;
	
	NSUInteger folderStackCount = 0;
	
	for (NSUInteger flattenedIndex = self.containerPlaylistRange.location - 1; flattenedIndex > 0; flattenedIndex--) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(self.parentContainer.container, (int)flattenedIndex);
		
		if (type == SP_PLAYLIST_TYPE_START_FOLDER && folderStackCount == 0) {
			sp_uint64 currentFolderId = sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, (int)flattenedIndex);
			return [self.parentContainer.session playlistFolderForFolderId:currentFolderId
															   inContainer:self.parentContainer];
		} else if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			folderStackCount--;
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			folderStackCount++;
		}
	}
	
	return nil;
}

-(NSArray *)parentFolders {
	
	NSMutableArray *parents = [NSMutableArray array];
	SPPlaylistFolder *parent = self;
	
	while ((parent = [parent parentFolder])) {
		[parents addObject:parent];
	}
	
	if ([parents count] > 0) {
		return [NSArray arrayWithArray:parents];
	} else {
		return nil;
	}
}

-(id)childAtFlattenedIndex:(NSUInteger)index {

	// Our direct child that contains the given index
	NSUInteger virtualIndex = [self virtualChildIndexForFlattenedIndex:index];
	
	if (virtualIndex != NSNotFound)
		return [[self mutableArrayValueForKey:@"playlists"] objectAtIndex:virtualIndex];
	
	return nil;
}

#pragma mark -

-(void)dealloc {
	self.session = nil;
	if (playlist != NULL)
		sp_playlist_release(playlist);
	self.parentContainer = nil;
	self.name = nil;
	self.parentContainer = nil;
    [super dealloc];
}
				
                     
@end

@implementation SPPlaylistFolder (SPPlaylistFolderInternal)

-(id)initWithPlaylistFolderId:(sp_uint64)anId 
					container:(SPPlaylistContainer *)aContainer
					inSession:(SPSession *)aSession {
    
    if ((self = [super init])) {
        self.session = aSession;
		self.parentContainer = aContainer;
		folderId = anId;
		[self rangeMayHaveChanged];
    }
    return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@ %@", [super description], self.name, [self valueForKey:@"playlists"]];
}

-(NSRange)containerPlaylistRange {
	return containerPlaylistRange;
}

-(void)setContainerPlaylistRange:(NSRange)range {
	containerPlaylistRange = range;
}

-(void)rangeMayHaveChanged {
	
	[self willChangeValueForKey:@"playlists"];
	
	NSRange newRange = {0,0};
	
	if (folderId == 0) {
		// Root folder! 
		newRange = NSMakeRange(0, sp_playlistcontainer_num_playlists(self.parentContainer.container));
	} else {
		BOOL startWasFound = NO;
		int playlistCount = sp_playlistcontainer_num_playlists(self.parentContainer.container);
		NSUInteger relativeFolderStackCount = 0;
		
		for (int currentIndex = 0; currentIndex < playlistCount; currentIndex++) {
			
			sp_playlist_type currentPlaylistType = sp_playlistcontainer_playlist_type(self.parentContainer.container, currentIndex);
			
			if (currentPlaylistType == SP_PLAYLIST_TYPE_START_FOLDER &&
				sp_playlistcontainer_playlist_folder_id(self.parentContainer.container, currentIndex) == folderId) {
				// Take this opportunity to take the name.
				if (self.name == nil) {
					char nameChars[256];
					sp_error nameError = sp_playlistcontainer_playlist_folder_name(self.parentContainer.container, (int)currentIndex, nameChars, sizeof(nameChars));
					if (nameError == SP_ERROR_OK) {
						self.name = [NSString stringWithUTF8String:nameChars];
					}
				}
				startWasFound = YES;
				newRange.location = currentIndex;
				newRange.length = 1;
				continue;
			}
			
			if (currentPlaylistType == SP_PLAYLIST_TYPE_START_FOLDER && startWasFound) {
				relativeFolderStackCount++;
				continue;
			}
			
			if (currentPlaylistType == SP_PLAYLIST_TYPE_END_FOLDER && startWasFound) {
				if (relativeFolderStackCount == 0) {
					newRange.length = (currentIndex - newRange.location) + 1;
					break;
				} else {
					relativeFolderStackCount--;
					continue;
				}
			}
		}
	}
	
	if (!NSEqualRanges(self.containerPlaylistRange, newRange))
		self.containerPlaylistRange = newRange;
	
	// Update subfolders
	for (id currentPlaylist in [self mutableArrayValueForKey:@"playlists"]) {
		if ([currentPlaylist isKindOfClass:[SPPlaylistFolder class]])
			[(SPPlaylistFolder *)currentPlaylist rangeMayHaveChanged];
	}
	
	[self performIntegrityCheck];
	
	[self didChangeValueForKey:@"playlists"];
}


-(NSUInteger)virtualChildIndexForFlattenedIndex:(NSUInteger)flattenedIndex {
	
	NSRange children = [self rangeOfChildObjects];
	NSUInteger lastChildIndex = children.location + (children.length - 1);
	
	if (flattenedIndex < children.location ||
		flattenedIndex > lastChildIndex) {
		return NSNotFound;
	}
	
	NSUInteger currentIndex = children.location;
	NSUInteger virtualIndex = 0;
	NSUInteger folderStackCount = 0;
	
	if (currentIndex == flattenedIndex)
		return virtualIndex;
	
	while (currentIndex <= lastChildIndex) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(parentContainer.container, (int)currentIndex);
		
		if (type == SP_PLAYLIST_TYPE_PLAYLIST && folderStackCount == 0) {
			// Normal playlist, increment as normal if it's not in a folder
			virtualIndex++;
		} else if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			// Folder start, increment if it's not in a folder.
			if (folderStackCount == 0)
				virtualIndex++;
			folderStackCount++;
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			// Reduce stack count.
			folderStackCount--;
		}
		
		if (currentIndex == flattenedIndex)
			return virtualIndex;
		
		currentIndex++;
	}
	
	return NSNotFound;
}

-(NSUInteger)flattenedIndexForVirtualChildIndex:(NSUInteger)virtualIndex {
	
	NSRange children = [self rangeOfChildObjects];
	
	if (virtualIndex == 0)
		return children.location;
	
	NSUInteger lastChildIndex = children.location + (children.length - 1);
	
	NSUInteger currentFlattenedIndex = children.location;
	NSInteger virtualIndexOfCurrentFlattenedIndex = -1;
	NSUInteger folderStackCount = 0;
	
	while (currentFlattenedIndex <= lastChildIndex) {
		
		sp_playlist_type type = sp_playlistcontainer_playlist_type(parentContainer.container, (int)currentFlattenedIndex);
		
		if (type == SP_PLAYLIST_TYPE_PLAYLIST && folderStackCount == 0) {
			// Normal playlist, increment as normal if it's not in a folder
			virtualIndexOfCurrentFlattenedIndex++;
		} else if (type == SP_PLAYLIST_TYPE_START_FOLDER) {
			// Folder start, increment if it's not in a folder.
			if (folderStackCount == 0)
				virtualIndexOfCurrentFlattenedIndex++;
			folderStackCount++;
		} else if (type == SP_PLAYLIST_TYPE_END_FOLDER) {
			// Reduce stack count.
			folderStackCount--;
		}
		
		if (virtualIndexOfCurrentFlattenedIndex == virtualIndex)
			return currentFlattenedIndex;
		
		currentFlattenedIndex++;
	}
	
	return NSNotFound;
}

@end

