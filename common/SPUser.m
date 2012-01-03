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

@interface SPUser ()

-(void)checkLoaded;
-(void)loadUserData;

@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, copy) NSString *canonicalName;
@property (nonatomic, readwrite, copy) NSString *displayName;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;

@end

@implementation SPUser

+(SPUser *)userWithUserStruct:(sp_user *)spUser inSession:(SPSession *)aSession {
    return [aSession userForUserStruct:spUser];
}

+(SPUser *)userWithURL:(NSURL *)userUrl inSession:(SPSession *)aSession {
	return [aSession userForURL:userUrl];
}

-(id)initWithUserStruct:(sp_user *)aUser inSession:(SPSession *)aSession {
	
	if (aUser == NULL) {
		[self release];
		return nil;
	}
	
    if ((self = [super init])) {
        user = aUser;
        sp_user_add_ref(user);
        
        [self checkLoaded];
    }
    return self;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@", [super description], self.canonicalName];
}

-(void)checkLoaded {
    BOOL userLoaded = sp_user_is_loaded(user);
    if (!userLoaded) {
        [self performSelector:_cmd
                   withObject:nil
                   afterDelay:.25];
    } else {
        [self loadUserData];
    }
}

-(void)loadUserData {
    
    [self setLoaded:sp_user_is_loaded(user)];
    
    if ([self isLoaded]) {
		
		sp_link *link = sp_link_create_from_user(user);
		if (link != NULL) {
			[self setSpotifyURL:[NSURL urlWithSpotifyLink:link]];
			sp_link_release(link);
		}
     
        const char *canonical = sp_user_canonical_name(user);
        if (canonical != NULL) {
            NSString *canonicalString = [NSString stringWithUTF8String:canonical];
            [self setCanonicalName:[canonicalString length] > 0 ? canonicalString : nil];
        }
        
        const char *display = sp_user_display_name(user);
        if (display != NULL) {
            NSString *displayString = [NSString stringWithUTF8String:display];
            [self setDisplayName:[displayString length] > 0 ? displayString : nil];
		}
    }
}

@synthesize spotifyURL;
@synthesize canonicalName;
@synthesize displayName;
@synthesize loaded;
@synthesize user;

-(void)dealloc {
    [self setCanonicalName:nil];
    [self setDisplayName:nil];
	[self setSpotifyURL:nil];
    
    session = nil;
    sp_user_release(user);
    [super dealloc];
}

@end
