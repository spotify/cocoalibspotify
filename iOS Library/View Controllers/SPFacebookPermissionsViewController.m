//
//  SPFacebookPermissionsViewController.m
//  CocoaLibSpotify iOS Library
//
//  Created by Daniel Kennett on 24/03/2012.
/*
 Copyright (c) 2012, Spotify AB
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

#import "SPFacebookPermissionsViewController.h"

@interface SPFacebookPermissionsViewController ()
@property (nonatomic, readwrite, copy) NSArray *permissions;
@end

@implementation SPFacebookPermissionsViewController

-(id)initWithPermissions:(NSArray *)somePermissions inSession:(SPSession *)aSession {
	
	self = [super initWithSession:aSession];
	
	if (self) {
		self.permissions = somePermissions;
		
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStyleBordered  target:self action:@selector(add)];
		
		NSMutableArray *jsPermissions = [NSMutableArray arrayWithCapacity:self.permissions.count];
		for (NSString *permission in self.permissions) {
			[jsPermissions addObject:[NSString stringWithFormat:@"\"%@\"", permission]];
		}
		
		[super loadDocument:@"permissions.en.html"
				   inFolder:@"mobilehulkpermissions"
					   page:0
			   stillLoading:NO
				 recentUser:nil
				   features:0];
		
		NSString *js = [NSString stringWithFormat:@"setPermissionsNeeded([%@])", [jsPermissions componentsJoinedByString:@", "]];
		[self runJSWhenLoaded:js];
		
	}
	return self;
}


@synthesize permissions;
@synthesize delegate;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - Actions

-(void)add {
	sp_signup_userdata_success success;
	success.success = true;
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_CONNECT_TO_FACEBOOK_COMPLETED, &success);
	[self.delegate signupPageDidAccept:self];
}

-(void)cancel {
	sp_signup_userdata_success success;
	success.success = false;
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_CONNECT_TO_FACEBOOK_COMPLETED, &success);
	[self.delegate signupPageDidCancel:self];
}

@end
