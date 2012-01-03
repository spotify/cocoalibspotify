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

#import "SPPlaylistItem+SPPlaylistItemOfflineExtensions.h"

@implementation SPPlaylistItem (SPPlaylistItemOfflineExtensions)

+(NSSet *)keyPathsForValuesAffectingOfflineTrackStatus {
	return [NSSet setWithObject:@"item.offlineStatus"];
}

-(NSString *)offlineTrackStatus {
	
	if (self.itemClass != [SPTrack class]) {
		return @"Not A Track";
	} else {
		
		SPTrack *track = self.item;
		
		switch (track.offlineStatus) {
			case SP_TRACK_OFFLINE_DONE:
				return @"Done";
				break;
			case SP_TRACK_OFFLINE_NO:
				return @"Not Offline";
				break;
			case SP_TRACK_OFFLINE_ERROR:
				return @"Error";
				break;
			case SP_TRACK_OFFLINE_LIMIT_EXCEEDED:
				return @"Offline Limit Hit";
				break;
			case SP_TRACK_OFFLINE_DOWNLOADING:
				return @"Downloading";
				break;
			case SP_TRACK_OFFLINE_WAITING:
				return @"Waiting";
				break;
			case SP_TRACK_OFFLINE_DONE_EXPIRED:
				return @"Done, Expired";
				break;
			case SP_TRACK_OFFLINE_DONE_RESYNC:
				return @"Done, Requires Resync";
				break;
			default:
				return @"Unknown";
				break;
		}
	}
}

@end
