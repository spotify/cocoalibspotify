//
//  SPURLExtensions.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 3/26/11.
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

#import "SPURLExtensions.h"


@implementation NSURL (SPURLExtensions)

+(NSURL *)urlWithSpotifyLink:(sp_link *)link {
	
	if (link == NULL) 
		return nil;
	
	char buffer[1024];
	NSUInteger linkLength = sp_link_as_string(link, buffer, sizeof(buffer));
	
	if (linkLength == 0) 
		return nil;
	
	return [NSURL URLWithString:[NSString stringWithUTF8String:buffer]];
}

+(NSString *)urlDecodedStringForString:(NSString *)encodedString {
	NSString *decoded = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
																							(CFStringRef)[encodedString stringByReplacingOccurrencesOfString:@"+" withString:@" "], 
																							CFSTR(""), 
																							kCFStringEncodingUTF8);
	return [decoded autorelease];
}

+(NSString *)urlEncodedStringForString:(NSString *)plainOldString {
	NSString *encoded = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
																			(CFStringRef)plainOldString,
																			NULL,
																			(CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
																			kCFStringEncodingUTF8);
	return [encoded autorelease];
}

-(sp_link *)createSpotifyLink {
	sp_link *link = sp_link_create_from_string([[self absoluteString] UTF8String]);
	return link;
}
	
-(sp_linktype)spotifyLinkType {
	
	sp_link *link = [self createSpotifyLink];
	if (link != NULL) {
		sp_linktype linkType = sp_link_type(link);
		sp_link_release(link);
		return linkType;
	}
	return SP_LINKTYPE_INVALID;
}


@end
