//
//  SPPlaylist.h
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

/** This class represents a list of items, be it a user's starred list, inbox, or a traditional "playlist". */

#import <Foundation/Foundation.h>
#import "CocoaLibSpotifyPlatformImports.h"

@class SPUser;
@class SPImage;
@class SPSession;
@protocol SPPlaylistDelegate;

@interface SPPlaylist : NSObject <SPPlaylistableItem> {
@private 
    sp_playlist *playlist;
    BOOL updating;
    BOOL loaded;
    BOOL collaborative;
    BOOL hasPendingChanges;
    __weak id <SPPlaylistDelegate> delegate;
    __weak SPSession *session;
    NSString *playlistDescription;
    NSString *name;
    SPImage *image;
    SPUser *owner;
	NSURL *spotifyURL;
	BOOL trackChangesAreFromLibSpotifyCallback;
	NSMutableArray *itemWrapper;
	NSArray *subscribers;
	float offlineDownloadProgress;
	sp_playlist_offline_status offlineStatus;
}

///----------------------------
/// @name Creating and Initializing Playlists
///----------------------------

/** Creates an SPPlaylist from the given opaque sp_playlist struct. 
 
 This convenience method creates an SPPlaylist object if one doesn't exist, or 
 returns a cached SPPlaylist if one already exists for the given struct.
 
 @param pl The sp_playlist struct to create an SPPlaylist for.
 @param aSession The SPSession the playlist should exist in.
 @return Returns the created SPPlaylist object. 
 */
+(SPPlaylist *)playlistWithPlaylistStruct:(sp_playlist *)pl inSession:(SPSession *)aSession;

/** Creates an SPPlaylist from the given Spotify playlist URL. 
 
 This convenience method creates an SPPlaylist object if one doesn't exist, or 
 returns a cached SPPlaylist if one already exists for the given URL.
 
 @warning *Important:* If you pass in an invalid playlist URL (i.e., any URL not
 starting `spotify:user:XXXX:playlist:`, this method will return `nil`.

 @param playlistURL The playlist URL to create an SPPlaylist for.
 @param aSession The SPSession the playlist should exist in.
 @return Returns the created SPPlaylist object. 
 */
+(SPPlaylist *)playlistWithPlaylistURL:(NSURL *)playlistURL inSession:(SPSession *)aSession;

/** Initializes an SPPlaylist from the given opaque sp_playlist struct. 
 
 @warning *Important:* For better performance and built-in caching, it is recommended
 you create SPPlaylist objects using +[SPPlaylist playlistWithPlaylistStruct:inSession:], 
 +[SPPlaylist playlistWithPlaylistURL:inSession:] or the instance methods on SPSession.
 
 @param pl The sp_playlist struct to create an SPPlaylist for.
 @param aSession The SPSession the playlist should exist in.
 @return Returns the created SPPlaylist object. 
 */
-(id)initWithPlaylistStruct:(sp_playlist *)pl inSession:(SPSession *)aSession;

///----------------------------
/// @name Properties
///----------------------------

/** Returns the playlist's delegate object. */
@property (nonatomic, readwrite, assign) __weak id <SPPlaylistDelegate> delegate;

/** Returns `YES` if the playlist has changes not yet recognised by the Spotify servers, otherwise `NO`. */
@property (nonatomic, readonly) BOOL hasPendingChanges;

/** Returns `YES` if the playlist is collaborative (can be edited by users other than the owner), otherwise `NO`. */
@property (nonatomic, readwrite, getter=isCollaborative) BOOL collaborative;

/** Returns `YES` if the playlist has finished loading and all data is available. */ 
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;

/** Returns `YES` if the playlist is marked for offline playback. */
@property (nonatomic, readwrite, getter=isMarkedForOfflinePlayback) BOOL markedForOfflinePlayback;

/** Returns `YES` if the playlist is being updated, otherwise `NO`. 
 
 Typically, you should delay UI updates while this property is set to `YES`.
 */ 
@property (nonatomic, readonly, getter=isUpdating) BOOL updating;

/** Returns the download progress of the playlist (between 0 and 1) is it is marked for offline sync. */
@property (nonatomic, readonly) float offlineDownloadProgress;

/** Returns the offline status of the playlist. Possible values:
 
 SP_PLAYLIST_OFFLINE_STATUS_NO 	
 Playlist is not offline enabled.
 
 SP_PLAYLIST_OFFLINE_STATUS_YES 	
 Playlist is synchronized to local storage.
 
 SP_PLAYLIST_OFFLINE_STATUS_DOWNLOADING 	
 This playlist is currently downloading. Only one playlist can be in this state any given time.
 
 SP_PLAYLIST_OFFLINE_STATUS_WAITING 	
 Playlist is queued for download.
 */
@property (nonatomic, readonly) sp_playlist_offline_status offlineStatus;

/** Returns the owner of the playlist, or `nil` if the playlist hasn't loaded yet. */
@property (nonatomic, readonly, retain) SPUser *owner;

/** Returns the opaque structure used by the C LibSpotify API. 
 
 @warning *Important:* This should only be used if you plan to directly use the 
 C LibSpotify API. The behaviour of CocoaLibSpotify is undefined if you use the C
 API directly on items that have CocoaLibSpotify objects associated with them. 
 */
@property (nonatomic, readonly) sp_playlist *playlist;

/** Returns the session object the playlist is loaded in. */
@property (nonatomic, readonly, assign) __weak SPSession *session;

/** Returns the Spotify URI of the playlist profile, for example: `spotify:user:sarnesjo:playlist:3p2c7mmML3fIUh5fcZ8Hcq` */
@property (nonatomic, readonly, copy) NSURL *spotifyURL;

/** Returns the subscribers to the playlist as an array of Spotify usernames. */
@property (nonatomic, readonly, retain) NSArray *subscribers;

///----------------------------
/// @name Metadata
///----------------------------

/** Returns the custom image for the playlist, or `nil` if the playlist hasn't loaded yet or it doesn't have a custom image. */
@property (nonatomic, readonly, retain) SPImage *image;

/** Returns the name of the playlist, or `nil` if the playlist hasn't loaded yet. */
@property (nonatomic, readwrite, copy) NSString *name;

/** Returns the custom description for the playlist, or `nil` if the playlist hasn't loaded yet or it doesn't have a custom description. */
@property (nonatomic, readonly, copy) NSString *playlistDescription;

///----------------------------
/// @name Working with Items
///----------------------------

/** Returns an array of SPPlaylistItem objects representing playlist's item order.
 
 This array is KVO compliant, and any changes made will be reflected in the user's account.
 
 @warning *Important:* You can add both `SPTrack` and `SPPlaylistItem` objects to this array.
 `SPTrack` objects will automatically be wrapped inside an `SPPlaylistItem`.
 
 @warning *Important:* If you need to move an item from one location in this list to another, please
 use `-moveItemsAtIndexes:toIndex:error:` for performance reasons.
 
 @see -moveItemsAtIndexes:toIndex:error:
 */
@property (nonatomic, readonly) NSMutableArray *items;

/** Move item(s) to another location in the list. 
 
 All indexes are given relative to the state of the item order before the move is executed. Therefore, you
 *don't* need to adjust the destination index to take into account items that will be moved from above it.
 
 @warning *Important:* This operation can fail, for example if you give invalid indexes. Please make sure 
 you check the result of this method.
 
 @param indexes The indexes of the items to move.
 @param newLocation The index the items should be moved to.
 @param error An NSError pointer to be filled if the operation fails.
 @return Returns `YES` if the operation succeeded, otherwise `NO`. 
 */
-(BOOL)moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)newLocation error:(NSError **)error;

@end

/** Delegate callbacks from SPPlaylist to help with item reordering. */

@protocol SPPlaylistDelegate <NSObject>
@optional

/** Called when one or more items in the playlist updated their metadata. 
 
 @param aPlaylist The playlist in which items updated their metadata.
 */
-(void)itemsInPlaylistDidUpdateMetadata:(SPPlaylist *)aPlaylist;

///----------------------------
/// @name Item Removal
///----------------------------

/** Called before one or more items in the playlist will be removed from the playlist. 
 
 @param aPlaylist The playlist in which items will be removed.
 @param items The items that will be removed.
 @param outgoingIndexes The indexes of the itemss.
 */
-(void)playlist:(SPPlaylist *)aPlaylist willRemoveItems:(NSArray *)items atIndexes:(NSIndexSet *)outgoingIndexes;

/** Called after one or more items in the playlist were removed from the playlist. 
 
 @warning *Important:* The index set passed to this method is not valid for the given items.
 
 @param aPlaylist The playlist in which items were removed.
 @param items The items that were be removed.
 @param theseIndexesArentValidAnymore The (now invalid) indexes of the items.
 */
-(void)playlist:(SPPlaylist *)aPlaylist didRemoveItems:(NSArray *)items atIndexes:(NSIndexSet *)theseIndexesArentValidAnymore;

///----------------------------
/// @name Item Addition
///----------------------------

/** Called before one or more items are added to the playlist. 
 
 @warning *Important:* The index set passed to this method is not valid for the given items.
 
 @param aPlaylist The playlist to which items will be added.
 @param items The items that will be added.
 @param theseIndexesArentYetValid The (invalid, for now) destination indexes of the items.
 */
-(void)playlist:(SPPlaylist *)aPlaylist willAddItems:(NSArray *)items atIndexes:(NSIndexSet *)theseIndexesArentYetValid;

/** Called after one or more items are added to the playlist. 
 
 @param aPlaylist The playlist in which items were added.
 @param items The items that were added.
 @param newIndexes The destination indexes of the items.
 */
-(void)playlist:(SPPlaylist *)aPlaylist didAddItems:(NSArray *)items atIndexes:(NSIndexSet *)newIndexes;

///----------------------------
/// @name Item Reordering
///----------------------------

/** Called before one or more items are moved within the playlist. 
 
 @param aPlaylist The playlist in which items will be moved.
 @param items The items that will be moved.
 @param oldIndexes The current indexes of the items.
 @param newIndexes The (invalid, for now) indexes that the items will end up at.
 */
-(void)playlist:(SPPlaylist *)aPlaylist willMoveItems:(NSArray *)items atIndexes:(NSIndexSet *)oldIndexes toIndexes:(NSIndexSet *)newIndexes;

/** Called after one or more items are moved within the playlist. 
 
 @param aPlaylist The playlist in which items will be moved.
 @param items The items that will be moved.
 @param oldIndexes The (invalid) old indexes of the items.
 @param newIndexes The now current indexes of the items.
 */
-(void)playlist:(SPPlaylist *)aPlaylist didMoveItems:(NSArray *)items atIndexes:(NSIndexSet *)oldIndexes toIndexes:(NSIndexSet *)newIndexes;

@end