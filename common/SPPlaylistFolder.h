//
//  SPPlaylistFolder.h
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

/** This class represents a playlist folder in the user's playlist list.
 
 @see SPPlaylistContainer
 */

#import <Foundation/Foundation.h>
#import "CocoaLibSpotifyPlatformImports.h"

@class SPPlaylistContainer;
@class SPSession;

@interface SPPlaylistFolder : NSObject {
    @private
    
	__weak SPPlaylistContainer *parentContainer;
	NSRange containerPlaylistRange;
	// ^ For performance and integrity checking - the first item should be the folder marker, 
	// the last the end folder marker. 
	
	NSString *name;
	sp_playlist *playlist;
	__weak SPSession *session;
	sp_uint64 folderId;
}

///----------------------------
/// @name Properties
///----------------------------

/** Returns the folder's ID, as used in the C LibSpotify API. 
 
 @warning *Important:* This should only be used if you plan to directly use the 
 C LibSpotify API. The behaviour of CocoaLibSpotify is undefined if you use the C
 API directly on items that have CocoaLibSpotify objects associated with them. 
 */
@property (nonatomic, readonly) sp_uint64 folderId;

/** Returns the name of the folder. */
@property (nonatomic, readonly, copy) NSString *name;

/** Returns the folder's containing SPPlaylistContainer. */
@property (nonatomic, readonly, assign) __weak SPPlaylistContainer *parentContainer;

/* Returns the folder's parent folder, or `nil` if the folder is at the top level of its container. */
-(SPPlaylistFolder *)parentFolder;

/* Returns the folder's parent folder stack, or `nil` if the folder is at the top level of its container. */
-(NSArray *)parentFolders;

/** Returns an array of SPPlaylist and/or SPPlaylistFolders representing the folder's child playlists.
 
 This array is KVO compliant, and any changes made will be reflected in the user's account.
 
 @warning *Important:* If you need to move a playlist from one location in this list to another, please
 use `-[SPPlaylistContainer movePlaylistOrFolderAtIndex:ofParent:toIndex:ofNewParent:error:]` for performance reasons.
 
 @see [SPPlaylistContainer movePlaylistOrFolderAtIndex:ofParent:toIndex:ofNewParent:error:]
 */
@property (nonatomic, readonly) NSMutableArray *playlists;

/** Returns the session the folder is loaded in. */
@property (nonatomic, readonly, assign) __weak SPSession *session;

@end
