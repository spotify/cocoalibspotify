//
//  SPPlaylistContainer.h
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

/** This class represents a list of playlists. In practice, it is only found when dealing with a user's playlist 
 list and can't be created manually. */

#import <Foundation/Foundation.h>
#import "CocoaLibSpotifyPlatformImports.h"

@class SPUser;
@class SPSession;
@class SPPlaylist;
@class SPPlaylistFolder;

@interface SPPlaylistContainer : NSObject {
    @private
    sp_playlistcontainer *container;
    __weak SPSession *session;
    SPPlaylistFolder *rootFolder;
    SPUser *owner;
	BOOL loaded;
}

///----------------------------
/// @name Properties
///----------------------------

/** Returns the opaque structure used by the C LibSpotify API. 
 
 @warning *Important:* This should only be used if you plan to directly use the 
 C LibSpotify API. The behaviour of CocoaLibSpotify is undefined if you use the C
 API directly on items that have CocoaLibSpotify objects associated with them. 
 */
@property (nonatomic, readonly, assign) sp_playlistcontainer *container;

/* Returns `YES` if the playlist container has loaded all playlist and folder data, otherwise `NO`. */
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;

/** Returns the owner of the playlist list. */
@property (nonatomic, readonly, retain) SPUser *owner;

/** Returns an array of SPPlaylist and/or SPPlaylistFolders representing the owner's playlists.
 
 This array is KVO compliant, and any changes made will be reflected in the user's account.
 
 @warning *Important:* If you need to move a playlist from one location in this list to another, please
 use `-movePlaylistOrFolderAtIndex:ofParent:toIndex:ofNewParent:error:` for performance reasons.
 
 @see movePlaylistOrFolderAtIndex:ofParent:toIndex:ofNewParent:error:
*/
@property (nonatomic, readonly) NSMutableArray *playlists;

/** Returns the session the list is loaded in. */
@property (nonatomic, readonly, assign) __weak SPSession *session;

///----------------------------
/// @name Working with Playlists and Folders
///----------------------------

/** Create a new, empty folder. 
 
 @param name The name of the new folder.
 @param error An error pointer that will be filled with an NSError if the operation fails.
 @return Returns the created folder (which will also be added to the start of the playlists property), or `nil` if the operation failed.
 */
-(SPPlaylistFolder *)createFolderWithName:(NSString *)name error:(NSError **)error;

/** Create a new, empty playlist. 
 
 @param name The name of the new playlist. Must be shorter than 256 characters and not consist of only whitespace.
 @return Returns the created playlist (which will also be added to the end of the playlists property), or `nil` if the operation failed.
 */
-(SPPlaylist *)createPlaylistWithName:(NSString *)name;

/** Move a playlist or folder to another location in the list. 
 
 @warning *Important:* This operation can fail, for example if you give invalid indexes or try to move 
 a folder into itself. Please make sure you check the result of this method.
 
 @param aPlaylistOrFolder The index of the playlist or folder in its parent (or the root list if it has no parent).
 @param existingParentFolderOrNil The parent folder the previous index refers to, or `nil` if there is no parent.
 @param newIndex The desired destination index in the destination parent folder (or root list if there's no parent).
 @param aParentFolderOrNil The new parent folder, or nil if there is no parent.
 @param err An NSError pointer to be filled if the operation fails.
 @return Returns `YES` if the operation succeeded, otherwise `NO`. 
 */
-(BOOL)movePlaylistOrFolderAtIndex:(NSUInteger)aPlaylistOrFolder 
						  ofParent:(SPPlaylistFolder *)existingParentFolderOrNil
						   toIndex:(NSUInteger)newIndex 
					   ofNewParent:(SPPlaylistFolder *)aParentFolderOrNil
							 error:(NSError **)err;
@end
