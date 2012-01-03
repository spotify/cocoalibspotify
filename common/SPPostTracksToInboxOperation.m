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

@property (nonatomic, readwrite, retain) SPSession *session;
@property (nonatomic, readwrite, copy) NSString *destinationUser;
@property (nonatomic, readwrite, copy) NSArray *tracks;
@property (nonatomic, readwrite, copy) NSString *message;

@property (nonatomic, readwrite, assign) __weak id <SPPostTracksToInboxOperationDelegate> delegate;

@end

void inboxpost_complete(sp_inbox *result, void *userdata);
void inboxpost_complete(sp_inbox *result, void *userdata) {
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	SPPostTracksToInboxOperation *operation = userdata;
	sp_error errorCode = sp_inbox_error(result);
	
	if (errorCode != SP_ERROR_OK) {
		if ([operation.delegate respondsToSelector:@selector(postTracksToInboxOperation:didFailWithError:)]) {
			[(id <SPPostTracksToInboxOperationDelegate>)operation.delegate postTracksToInboxOperation:operation didFailWithError:[NSError spotifyErrorWithCode:errorCode]];
		}
	} else {
		if ([operation.delegate respondsToSelector:@selector(postTracksToInboxOperationDidSucceed:)]) {
			[(id <SPPostTracksToInboxOperationDelegate>)operation.delegate postTracksToInboxOperationDidSucceed:operation];
		}
	}
	
	[pool drain]; 
}

@implementation SPPostTracksToInboxOperation

+(SPPostTracksToInboxOperation *)sendTracks:(NSArray *)tracksToSend
									 toUser:(NSString *)user 
									message:(NSString *)aFriendlyGreeting
								  inSession:(SPSession *)aSession
								   delegate:(id <SPPostTracksToInboxOperationDelegate>)completionDelegate {
	
	return [[[SPPostTracksToInboxOperation alloc] initBySendingTracks:tracksToSend
															   toUser:user
															  message:aFriendlyGreeting
															inSession:aSession
															 delegate:completionDelegate] autorelease];
}

-(id)initBySendingTracks:(NSArray *)tracksToSend
				  toUser:(NSString *)user 
				 message:(NSString *)aFriendlyGreeting
			   inSession:(SPSession *)aSession
				delegate:(id <SPPostTracksToInboxOperationDelegate>)completionDelegate {

	if ((self = [super init])) {
		
		if (aSession != nil && [tracksToSend count] > 0 && [user length] > 0) {
			
			self.session = aSession;
			self.destinationUser = user;
			self.message = aFriendlyGreeting;
			self.tracks = tracksToSend;
			self.delegate = (id)completionDelegate;
			
			
			int trackCount = (int)[self.tracks count];
			sp_track *trackArray[trackCount];
			
			for (NSUInteger i = 0; i < trackCount; i++) {
				trackArray[i] = [(SPTrack *)[self.tracks objectAtIndex:i] track];
			}
			
			sp_track *const *trackArrayPtr = (sp_track *const *)&trackArray;
			
			inboxOperation = sp_inbox_post_tracks(self.session.session, 
												  [self.destinationUser UTF8String],
												  trackArrayPtr, 
												  trackCount, 
												  [self.message UTF8String], 
												  &inboxpost_complete, 
												  self);
		} else {
			[self release];
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

@synthesize delegate;
@synthesize inboxOperation;

- (void)dealloc {
	self.session = nil;
	self.destinationUser = nil;
	self.message = nil;
	self.tracks = nil;
	self.delegate = nil;
	
	if (inboxOperation != NULL) {
		sp_inbox_release(inboxOperation);
		inboxOperation = NULL;
	}
	
    [super dealloc];
}

@end
