//
//  SPUser.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/21/11.
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

#import "SPUser.h"
#import "SPSession.h"
#import "SPURLExtensions.h"
#import "SPSessionInternal.h"

@interface SPUser ()

-(BOOL)checkLoaded;
-(void)loadUserData;

@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, copy) NSString *canonicalName;
@property (nonatomic, readwrite, copy) NSString *displayName;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite) sp_user *user;
@property (nonatomic, readwrite, assign) __unsafe_unretained SPSession *session;

@end

@implementation SPUser

+(SPUser *)userWithUserStruct:(sp_user *)spUser inSession:(SPSession *)aSession {
    return [aSession userForUserStruct:spUser];
}

+(void)userWithURL:(NSURL *)userUrl inSession:(SPSession *)aSession callback:(void (^)(SPUser *user))block {
	[aSession userForURL:userUrl callback:block];
}

-(id)initWithUserStruct:(sp_user *)aUser inSession:(SPSession *)aSession {
	
	if (aUser == NULL) {
		return nil;
	}
		
	SPAssertOnLibSpotifyThread();
	
    if ((self = [super init])) {
        self.user = aUser;
        self.session = aSession;

		sp_user_add_ref(self.user);

        if (!sp_user_is_loaded(self.user)) {
            [aSession addLoadingObject:self];
        } else {
            [self loadUserData];
        }
    }
    return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.canonicalName];
}

-(BOOL)checkLoaded {
	
	SPAssertOnLibSpotifyThread();
	
	BOOL userLoaded = sp_user_is_loaded(self.user);

    if (userLoaded)
        [self loadUserData];
	
	return userLoaded;
}

-(void)loadUserData {

    SPAssertOnLibSpotifyThread();
	
	BOOL userLoaded = sp_user_is_loaded(self.user);
	NSURL *url = nil;
	NSString *canonicalString = nil;
	NSString *displayString = nil;
	
	if (userLoaded) {
		
		sp_link *link = sp_link_create_from_user(self.user);
		if (link != NULL) {
			url = [NSURL urlWithSpotifyLink:link];
			sp_link_release(link);
		}
		
		const char *canonical = sp_user_canonical_name(self.user);
		if (canonical != NULL) {
			canonicalString = [NSString stringWithUTF8String:canonical];
		}
		
		const char *display = sp_user_display_name(self.user);
		if (display != NULL) {
			displayString = [NSString stringWithUTF8String:display];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.canonicalName = [canonicalString length] > 0 ? canonicalString : nil;
			self.displayName = [displayString length] > 0 ? displayString : nil;
			self.spotifyURL = url;
			self.loaded = userLoaded;
		});
	}
}

@synthesize spotifyURL;
@synthesize canonicalName;
@synthesize displayName;
@synthesize loaded;
@synthesize user = _user;
@synthesize session;

-(sp_user *)user {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif
	return _user;
}

-(void)dealloc {
	sp_user *outgoing_user = _user;
	_user = NULL;
	dispatch_libspotify_async(^() {if (outgoing_user) sp_user_release(outgoing_user); });
}

@end
