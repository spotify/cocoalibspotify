//
//  SPSession.h
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

/** This class provides core functionality for interacting with Spotify. You must have a valid, logged-in
 SPSession object before using any other part of the API.
 
 To log in and use CocoaLibSpotify, you need two things:
 
 - An application key, available at the [Spotify Developers Site](http://developer.spotify.com/).
 - A user account with the Premium subscription level.
 
Playback
 
 Please note that CocoaLibSpotify does _not_ push audio data to the system's audio
 output. To hear tracks, you need to push the raw audio data provided to your application
 as you see fit. See the SimplePlayback sample project for an example of how to do this.
 */

#import <Foundation/Foundation.h>
#import "CocoaLibSpotifyPlatformImports.h"

@class SPPlaylist;
@class SPPlaylistFolder;
@class SPPlaylistContainer;
@class SPTrack;
@class SPUser;
@class SPSearch;
@class SPAlbum;
@class SPArtist;
@class SPImage;
@class SPPostTracksToInboxOperation;
@protocol SPSessionDelegate;
@protocol SPSessionPlaybackDelegate;
@protocol SPPostTracksToInboxOperationDelegate;
@protocol SPSessionPlaybackProvider;

@interface SPSession : NSObject <SPSessionPlaybackProvider> {
    @private
    sp_session *session;
	BOOL playing;
    SPPlaylist *inboxPlaylist;
    SPPlaylist *starredPlaylist;
    SPPlaylistContainer *userPlaylists;
    NSMutableDictionary *trackCache;
    NSMutableDictionary *userCache;
	NSMutableDictionary *playlistCache;
    __weak id <SPSessionDelegate> delegate;
    __weak id <SPSessionPlaybackDelegate> playbackDelegate;
    SPUser *user;
	NSLocale *locale;
	NSError *offlineSyncError;
    NSString *userAgent;
	sp_connectionstate _connectionState;
	NSDictionary *offlineStatistics;
	NSUInteger offlinePlaylistsRemaining;
	NSUInteger offlineTracksRemaining;
	BOOL offlineSyncing;
}

/** Returns a shared SPSession object. 
 
 This is a convenience method for creating and storing a single SPSession instance.
 
 @warning *Important:* The C API that CocoaLibSpotify uses (LibSpotify) doesn't 
 support using multiple sessions in the same process. While you can either create and 
 store your SPSession object using this convenience method or yourself using -[SPSession init],
 make sure you only have _one_ instance of SPSession active in your process at a time.
 
 @warning *Important:* This will return `nil` until +[SPSession initializeSharedSessionWithApplicationKey:userAgent:error:] is
 successfully called.

 
 */
+(SPSession *)sharedSession;

/** Initializes the shared SPSession object.
 
 Your application key and user agent must be valid to create an SPSession object.
 
 @warning *Important:* The C API that CocoaLibSpotify uses (LibSpotify) doesn't 
 support using multiple sessions in the same process. While you can either create and 
 store your SPSession object using this convenience method or yourself using -[SPSession initWithApplicationKey:userAgent:error:],
 make sure you only have _one_ instance of SPSession active in your process at a time.
 
 @param appKey Your application key as an NSData.
 @param userAgent Your application's user agent (for example, com.yourcompany.MyGreatApp).
 @param error An error pointer to be filled with an NSError should a login problem occur. 
 */
+(void)initializeSharedSessionWithApplicationKey:(NSData *)appKey
									   userAgent:(NSString *)userAgent
										   error:(NSError **)error;

/** The "debug" build ID of libspotify.
 
 This could be useful to display somewhere deep down in the user interface in 
 case you (or Spotify) would like to know the exact version running. 
 
 @return Returns an NSString representing the build ID of the currently running version of libspotify.
 */
+(NSString *)libSpotifyBuildId;

///----------------------------
/// @name Logging In and Setup
///----------------------------

/** Initialize a new SPSession object.
 
 Your application key and user agent must be valid to create an SPSession object. This is SPSession's designated initializer.
 
@param appKey Your application key as an NSData.
@param userAgent Your application's user agent (for example, com.yourcompany.MyGreatApp).
@param error An error pointer to be filled with an NSError should a login problem occur.
@return Returns a newly initialised SPSession object.
 */
-(id)initWithApplicationKey:(NSData *)appKey
				  userAgent:(NSString *)userAgent
					  error:(NSError **)error;

/** Attempt to login to the Spotify service.
 
 Login success or fail methods will be called on the session's delegate.
 
@warning *Important:* You must have successfully logged in to the Spotify service before using 
 most other API methods.
 
 @param userName The username of the user who wishes to log in.
 @param password The password for the user who wishes to log in.
 @param rememberMe `YES` if the user's credentials should be saved in libspotify's encrypted store, otherwise `NO`.
 */
-(void)attemptLoginWithUserName:(NSString *)userName 
					   password:(NSString *)password
			rememberCredentials:(BOOL)rememberMe;

/** Attempt to login to the Spotify service using previously stored credentials.
 
 Login success or fail methods will be called on the session's delegate. 
 
 @param error An error pointer to be filled with an NSError should a login problem occur.
 @return Returns `YES` if user credentials had been stored and the login attempt began successfully.
 */
-(BOOL)attemptLoginWithStoredCredentials:(NSError **)error;

/** The username saved in the stored credentials.
 
 @return Returns the username that will be logged in with -[SPSession attemptLoginWithStoredCredentials:], or 
 `nil` if there are no stored credentials.
 */
-(NSString *)storedCredentialsUserName;

/** Remove stored credentials from the encrypted store.
 
 This method will cleanly log out from the Spotify service and clear any in-memory caches. 
 Called automatically when the instance is deallocated. 
 */
-(void)forgetStoredCredentials;

/** Log out from the Spotify service.
 
 This method will cleanly log out from the Spotify service and clear any in-memory caches. 
 Called automatically when the instance is deallocated.
 */
-(void)logout;

/** Returns the current connection state.
 
 Possible values: 
 
 SP_CONNECTION_STATE_LOGGED_OUT 	
 User not yet logged in.
 
 SP_CONNECTION_STATE_OFFLINE
 User is logged in but in offline mode.
 
 SP_CONNECTION_STATE_LOGGED_IN 	
 Logged in against a Spotify access point.
 
 SP_CONNECTION_STATE_DISCONNECTED 	
 Was logged in, but has now been disconnected.
 
 SP_CONNECTION_STATE_UNDEFINED 	
 The connection state is undefined.
 */
@property (nonatomic, readonly) sp_connectionstate connectionState;

/** Set the maximum cache size, in megabytes. 
 
 Set to 0 (the default) to automatically manage the cache, using at most 10% of the free disk space.
 
 @param maximumCacheSizeMB The maxiumum cache size, in MB, or 0 to automatically manage disk space.
 */
-(void)setMaximumCacheSizeMB:(size_t)maximumCacheSizeMB;

/** Set the preferred audio bitrate for playback.
 
 The default is to play the highest quality stream available. 
 
 @param bitrate The preferred bitrate for streaming. 
 */
-(void)setPreferredBitrate:(sp_bitrate)bitrate;

///----------------------------
/// @name Properties
///----------------------------

/** Returns the current delegate object. */
@property (nonatomic, assign) __weak id <SPSessionDelegate> delegate;

/** Returns the opaque structure used by the C LibSpotify API. 
 
 @warning *Important:* This should only be used if you plan to directly use the 
 C LibSpotify API. The behaviour of CocoaLibSpotify is undefined if you use the C
 API directly on items that have CocoaLibSpotify objects associated with them. 
 */
@property (nonatomic, readonly) sp_session *session;

/** Returns the user agent value the session was initialized with. */
@property (nonatomic, copy, readonly) NSString *userAgent;

///----------------------------
/// @name Offline Syncing
///----------------------------

/** Returns `YES` if tracks are currently being downloaded for offline playback, otherwise `NO`. */
@property (nonatomic, readonly, getter=isOfflineSyncing) BOOL offlineSyncing;

/** Returns the number of tracks still waiting to be downloaded for offline playback. */
@property (nonatomic, readonly) NSUInteger offlineTracksRemaining;

/** Returns the number of playlists still waiting to be downloaded for offline playback. */
@property (nonatomic, readonly) NSUInteger offlinePlaylistsRemaining;

/** Returns a dictionary containing information about any offline sync activity. See Contants for keys. */
@property (nonatomic, readonly, copy) NSDictionary *offlineStatistics;

/** Returns the time until the user needs to reconnect to Spotify to renew offline syncing keys. */
@property (nonatomic, readonly) NSTimeInterval offlineKeyTimeRemaining;

/** Returns the last error encountered during offline syncing, or `nil` if there is no problem. */
@property (nonatomic, readonly, retain) NSError *offlineSyncError;

///----------------------------
/// @name User Content
///----------------------------

/** Returns the logged in user's inbox playlist.
 
 The inbox playlist contains tracks sent to the user by other Spotify users, and is 
 updated as new tracks are sent to the user. 
 */ 
@property (nonatomic, readonly, retain) SPPlaylist *inboxPlaylist;

/** Returns the locale of the logged-in user. */
@property (nonatomic, readonly, retain) NSLocale *locale;

/** Returns the logged in user's starred playlist.
 
 The starred playlist contains tracks starred by the user, and is updated as new tracks are
 starred or unstarred.
 */ 
@property (nonatomic, readonly, retain) SPPlaylist *starredPlaylist;

/** Returns the current logged in user. */
@property (nonatomic, readonly, retain) SPUser *user;

/** Returns an SPPlaylistContainer object that contains the user's playlists.
 
 @see SPPlaylistContainer
 */
@property (nonatomic, readonly, retain) SPPlaylistContainer *userPlaylists;

/** Send tracks to another Spotify user.
 
 @warning *Important:* Tracks will be posted to the given user as soon as this
 method is called. Be sure you want to post the tracks before doing so!
 
 @param tracks An array of SPTrack objects to send.
 @param targetUserName The username of the user to send the tracks to.
 @param aFriendlyMessage The message to send with the tracks, if any.
 @param operationDelegate The delegate to send success/failure messages to.
 @return Returns an SPPostTracksToInboxOperation object representing the operation.
 @see SPPostTracksToInboxOperation
 @see SPPostTracksToInboxOperationDelegate
 */
-(SPPostTracksToInboxOperation *)postTracks:(NSArray *)tracks 
							  toInboxOfUser:(NSString *)targetUserName
								withMessage:(NSString *)aFriendlyMessage
								   delegate:(id <SPPostTracksToInboxOperationDelegate>)operationDelegate;

///----------------------------
/// @name Accessing Content by URL
///----------------------------

/** Returns an SPAlbum object representing the given URL, or `nil` if the URL is not a valid album URL. 
 
 @param url The URL of the album.
 */
-(SPAlbum *)albumForURL:(NSURL *)url;

/** Returns an SPArtist object representing the given URL, or `nil` if the URL is not a valid artist URL.
 
 @param url The URL of the artist.
 */
-(SPArtist *)artistForURL:(NSURL *)url;

/** Returns an SPImage object representing the given URL, or `nil` if the URL is not a valid image URL.
 
 @param url The URL of the image.
 */
-(SPImage *)imageForURL:(NSURL *)url;

/** Returns an SPPlaylist object representing the given URL, or `nil` if the URL is not a valid playlist URL.
 
 @param url The URL of the playlist.
 */
-(SPPlaylist *)playlistForURL:(NSURL *)url;

/** Returns an SPSearch object representing the given URL, or `nil` if the URL is not a valid search URL. 
 
 @param url The URL of the search query.
 */
-(SPSearch *)searchForURL:(NSURL *)url;

/** Returns an SPTrack object representing the given URL, or `nil` if the URL is not a valid track URL. 
 
 @param url The URL of the track.
 */
-(SPTrack *)trackForURL:(NSURL *)url;

/** Returns an SPUser object representing the given URL, or `nil` if the URL is not a valid user URL. 
 
 @param url The URL of the user.
 */
-(SPUser *)userForURL:(NSURL *)url;

/** Returns an object representation of the given Spotify URL.

 This method works just like -albumForURL:, -artistForURL: and so on, except that it works out 
 what the given URL represents and returns that for you.
 
 @param aSpotifyUrlOfSomeKind A Spotify URL (starting `spotify:`).
 @param linkType A pointer to an sp_linktype variable, which will be filled with the link type if not NULL.
 @return Returns an SPAlbum, SPArtist, SPPlaylist, SPSearch, SPTrack or SPUser object for the given URL, or `nil` if the URL is invalid.
 */
-(id)objectRepresentationForSpotifyURL:(NSURL *)aSpotifyUrlOfSomeKind linkType:(sp_linktype *)linkType;

///----------------------------
/// @name Accessing Arbitrary Content
///----------------------------

/** Create and cache an SPPlaylist for the given sp_playlist struct from the C LibSpotify API.
 
 This method caches SPPlaylist objects using the same cache the +[SPPlaylist playlist...] 
 convenience methods use.
 
 @param playlist The sp_playlist struct.
 @return Returns the created or cached SPPlaylist object.
 */
-(SPPlaylist *)playlistForPlaylistStruct:(sp_playlist *)playlist;

/** Create and cache an SPPlaylistFolder for the given folder ID from the C LibSpotify API.
 
 This method caches SPPlaylistFolder objects by ID.
 
 @param playlistId The folder ID.
 @param aContainer The SPPlaylistContainer that contains the given folder.
 @return Returns the created or cached SPPlaylistFolder object.
 */
-(SPPlaylistFolder *)playlistFolderForFolderId:(sp_uint64)playlistId inContainer:(SPPlaylistContainer *)aContainer;

/** Create and cache an SPTrack for the given sp_track struct from the C LibSpotify API.
 
 This method caches SPTrack objects using the same cache the +[SPTrack track...] 
 convenience methods use.
 
 @param track The sp_track struct.
 @return Returns the created or cached SPTrack object.
 */
-(SPTrack *)trackForTrackStruct:(sp_track *)track;

/** Create and cache an SPUser for the given sp_user struct from the C LibSpotify API.
 
 This method caches SPUser objects using the same cache the +[SPUser user...] 
 convenience methods use.
 
 @param user The sp_user struct.
 @return Returns the created or cached SPUser object.
 */
-(SPUser *)userForUserStruct:(sp_user *)user;

///----------------------------
/// @name Audio Playback
///----------------------------

/** Returns `YES` if the session is employing volume normalization (that is, attempts to keep the 
 sound level of each track the same), otherwise `NO`.
 
 @warning *Important:* This property currently has no effect on iOS platforms.
 */
@property (nonatomic, readwrite, getter=isUsingVolumeNormalization) BOOL usingVolumeNormalization;

/** Returns `YES` if the session is currently playing a track, otherwise `NO`. */
@property (nonatomic, readwrite, getter=isPlaying) BOOL playing;

/** Returns the session's playback delegate object.
 
 The playback delegate is responsible for pushing raw audio data provided by the session
 to the system's audio output. See the SimplePlayback sample project for an example of how to do this.
 */
@property (nonatomic, nonatomic, assign) __weak id <SPSessionPlaybackDelegate> playbackDelegate;

/** Preloads playback assets for the given track.
 
 For smooth changes between tracks, you can use this method to start loading track playback 
 data before the track needs to be played. The Spotify client does this a few seconds before moving 
 to the next track during normal playback.
 
 @param aTrack The track to preload.
 @param error An NSError pointer that will be filled with any error that occurs.
 @return Returns `YES` if loading started successfully, or `NO` if the track cannot be played.
 */
-(BOOL)preloadTrackForPlayback:(SPTrack *)aTrack error:(NSError **)error;

/** Start playing the given track.
 
 @param aTrack The track to play.
 @param error An NSError pointer that will be filled with any error that occurs.
 @return Returns `YES` if playback started successfully, or `NO` if the track cannot be played.
 */
-(BOOL)playTrack:(SPTrack *)aTrack error:(NSError **)error;

/** Seek the current playback position to the given time. 
 
 @param offset The time at which to seek to. Must be between 0.0 and the duration of the playing track.
 */
-(void)seekPlaybackToOffset:(NSTimeInterval)offset;

/** Unload playback resources from memory. 
 
 Call this when you're done playing to free up some memory. Called automatically on
 instance deallocation. 
 */
-(void)unloadPlayback;

@end

/** General delegate callbacks from SPSession. For playback-related callbacks, see SPSessionPlaybackDelegate. */

@protocol SPSessionDelegate <NSObject>
@optional

///----------------------------
/// @name Logging In and Out
///----------------------------

/** Called when the given session has logged in successfully.
 
 @param aSession The session that logged in. 
 */
-(void)sessionDidLoginSuccessfully:(SPSession *)aSession;

/** Called when the given session could not log in successfully.
 
 @param aSession The session that failed to log in. 
 @param error An NSError object describing the failure.
 */
-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error;

/** Called when the given session has logged out.
 
 @param aSession The session that logged out. 
 */
-(void)sessionDidLogOut:(SPSession *)aSession;

///----------------------------
/// @name Communicating With The User
///----------------------------

/** Called when the Spotify service would like to display a message to the user. 
 
 In the desktop client, these are shown in a blueish toolbar just below the search box.
 
 @param aSession The session that received the message. 
 @param aMessage The message to be displayed..
 */
-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage;

///----------------------------
/// @name Metadata
///----------------------------

/** Called when metadata has been updated.
 
 If you have cached metadata yourself, you should purge your caches and fetch new versions.
 
 @param aSession The session updated its metadata.
 */
-(void)sessionDidChangeMetadata:(SPSession *)aSession;

///----------------------------
/// @name Networking and Debug
///----------------------------

/** Called when there is a connection error, and CocoaLibSpotify has problems reconnecting
 to the Spotify service. Can be called multiple times (as long as the problem is present).
 
 @param aSession The session that encountered a problem. 
 @param error An NSError object describing the failure.
 */
-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error;

/** Called when a log-worthy message is generated by the Spotify service.
 
 @warning *Important:* This method will be called very frequently if implemented. Please
 refrain from mindlessly logging these to the console in a release application to aid the user's 
 sainity.
 
 @param aSession The session that is sending the log message. 
 @param aMessage The message to be logged.
 */
-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage;

@end

/** Delegate callbacks from SPSession specifically to do with audio playback. */

@protocol SPSessionPlaybackDelegate <NSObject>
@optional

/** Called when playback was paused because the Spotify account was used elsewhere.
 
 @param aSession The session that paused playback. 
 */
-(void)sessionDidLosePlayToken:(id <SPSessionPlaybackProvider>)aSession;

/** Called when playback stopped naturally at the end of a track.
 
 @param aSession The session that stopped playback. 
 */
-(void)sessionDidEndPlayback:(id <SPSessionPlaybackProvider>)aSession;

/** Called when playback stopped due to a streaming error. 
 
 @param aSession The session that stopped playback. 
 @param error The error that occurred.
 */
-(void)session:(id <SPSessionPlaybackProvider>)aSession didEncounterStreamingError:(NSError *)error;

/** Called when audio data has been decompressed and should be pushed to the audio buffers. 
 
 See the SimplePlayback sample project for an example of how to implement audio playback.
 
 @warning *Important:* This function is called from an internal session thread - you need to have 
 proper synchronization!
 
 @warning *Important:* If this method is called with a frameCount of 0, an "audio discontinuity" has occurred - 
 for example, the user has seeked playback to another part of the track. You should clear audio buffers and prepare
 for new audio.
 
 @warning *Important:* This function must never block. If your output buffers are full you must 
 return 0 to signal that the library should retry delivery in a short while.
 
 @param aSession The session providing the audio data.
 @param audioFrames A buffer containing the audio data.
 @param frameCount The number of frames in the buffer.
 @param audioFormat An sp_audioformat struct containing information about the audio format.
 @return Number of frames consumed. This value can be used to rate limit 
 the output from the library if your output buffers are saturated. Delivery will 
 be retried in about 100ms.
 */
-(NSInteger)session:(id <SPSessionPlaybackProvider>)aSession shouldDeliverAudioFrames:(const void *)audioFrames ofCount:(NSInteger)frameCount format:(const sp_audioformat *)audioFormat;

@end

///----------------------------
/// @name Offline Sync Statistics Keys
///----------------------------

/** @constant The number of tracks that have been copied as an `NSNumber`. */
static NSString * const SPOfflineStatisticsCopiedTrackCountKey = @"SPOfflineStatisticsCopiedTrackCount";

/** The data size of tracks, in bytes, that have been copied as an `NSNumber`. */
static NSString * const SPOfflineStatisticsCopiedTrackSizeKey = @"SPOfflineStatisticsCopiedTrackSize";

/** The number of tracks that were already offline synced before this operation started as an `NSNumber`. */
static NSString * const SPOfflineStatisticsDoneTrackCountKey = @"SPOfflineStatisticsDoneTrackCount";

/** The data size of tracks, in bytes, that were already offline synced before this operation started as an `NSNumber`. */
static NSString * const SPOfflineStatisticsDoneTrackSizeKey = @"SPOfflineStatisticsDoneTrackSize";

/** The number of tracks that are left to sync as an `NSNumber`. */
static NSString * const SPOfflineStatisticsQueuedTrackCountKey = @"SPOfflineStatisticsQueuedTrackCount";

/** The data size of tracks, in bytes, that are left to sync as an `NSNumber`. */
static NSString * const SPOfflineStatisticsQueuedTrackSizeKey = @"SPOfflineStatisticsQueuedTrackSize";

/** The number of tracks that failed to be offline synced as an `NSNumber`. */
static NSString * const SPOfflineStatisticsFailedTrackCountKey = @"SPOfflineStatisticsFailedTrackCount";

/** The number of tracks that will not be copied as an `NSNumber`. */
static NSString * const SPOfflineStatisticsWillNotCopyTrackCountKey = @"SPOfflineStatisticsWillNotCopyTrackCount";

/** Whether tracks are currently being synced as a boolean `NSNumber`. */
static NSString * const SPOfflineStatisticsIsSyncingKey = @"SPOfflineStatisticsIsSyncing";
