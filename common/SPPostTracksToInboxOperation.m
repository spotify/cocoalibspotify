//
//  SPPostTracksToInboxOperation.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 4/24/11.
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

#import "SPPostTracksToInboxOperation.h"
#import "SPSession.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"

@interface SPPostTracksToInboxOperation ()

@property (nonatomic, readwrite, strong) SPSession *session;
@property (nonatomic, readwrite, copy) NSString *destinationUser;
@property (nonatomic, readwrite, copy) NSArray *tracks;
@property (nonatomic, readwrite, copy) NSString *message;

@property (nonatomic, readwrite, assign) sp_inbox *inboxOperation;
@property (nonatomic, readwrite, copy) SPErrorableOperationCallback completionBlock;

@end

void inboxpost_complete(sp_inbox *result, void *userdata);
void inboxpost_complete(sp_inbox *result, void *userdata) {
	
	@autoreleasepool {
		SPPostTracksToInboxOperation *operation = (__bridge_transfer SPPostTracksToInboxOperation *)userdata;
		sp_error errorCode = sp_inbox_error(result);
		
		if (operation.inboxOperation != NULL) {
			sp_inbox_release(operation.inboxOperation);
			operation.inboxOperation = NULL;
		}
		
		NSError *error = nil;
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (operation.completionBlock) operation.completionBlock(error);
			operation.completionBlock = nil;
		});
	}
}

@implementation SPPostTracksToInboxOperation

+(SPPostTracksToInboxOperation *)sendTracks:(NSArray *)tracksToSend
									 toUser:(NSString *)user 
									message:(NSString *)aFriendlyGreeting
								  inSession:(SPSession *)aSession
								   callback:(SPErrorableOperationCallback)block {
	
	return [[SPPostTracksToInboxOperation alloc] initBySendingTracks:tracksToSend
															   toUser:user
															  message:aFriendlyGreeting
															inSession:aSession
															 callback:block];
}

-(id)initBySendingTracks:(NSArray *)tracksToSend
				  toUser:(NSString *)user 
				 message:(NSString *)aFriendlyGreeting
			   inSession:(SPSession *)aSession
				callback:(SPErrorableOperationCallback)block {

	if ((self = [super init])) {
		
		if (aSession != nil && [tracksToSend count] > 0 && [user length] > 0) {
			
			self.session = aSession;
			self.destinationUser = user;
			self.message = aFriendlyGreeting;
			self.tracks = tracksToSend;
			self.completionBlock = block;
			
			dispatch_libspotify_async(^{
				
				int trackCount = (int)self.tracks.count;
				sp_track *trackArray[trackCount];
				
				for (NSUInteger i = 0; i < trackCount; i++) {
					trackArray[i] = [(SPTrack *)[self.tracks objectAtIndex:i] track];
				}
				
				sp_track *const *trackArrayPtr = (sp_track *const *)&trackArray;
				
				self.inboxOperation = sp_inbox_post_tracks(aSession.session, 
														   [user UTF8String],
														   trackArrayPtr, 
														   trackCount, 
														   [aFriendlyGreeting UTF8String], 
														   &inboxpost_complete, 
														   (__bridge_retained void *)(self));
			});
			
			
		} else {
			return nil;
		}
	}
	return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: Sending to %@: %@", [super description], self.destinationUser, self.tracks];
}

@synthesize session;
@synthesize destinationUser;
@synthesize tracks;
@synthesize message;

@synthesize completionBlock;
@synthesize inboxOperation = _inboxOperation;

-(sp_inbox *)inboxOperation {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif
	return _inboxOperation;
}

- (void)dealloc {
	self.completionBlock = nil;
}

@end
