//
//  SPLoginViewController.m
//  Simple Player
//
//  Created by Daniel Kennett on 10/3/11.
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

#import "SPLoginViewController.h"
#import "CocoaLibSpotify.h"

@implementation SPLoginViewController
@synthesize usernameField;
@synthesize passwordField;
@synthesize loginButton;
@synthesize spinner;

-(id)init {
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return [self initWithNibName:@"SPLoginViewController_iPad" bundle:nil];
	} else {
		return [self initWithNibName:@"SPLoginViewController_iPhone" bundle:nil];
	}
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (IBAction)performLogin:(id)sender {
	
	if (self.usernameField.text.length == 0 || self.passwordField.text.length == 0) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
														message:@"Please enter your username and password"
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
		[[alert autorelease] show];

		return;
	}

	[[NSUserDefaults standardUserDefaults] setValue:usernameField.text forKey:@"username"];
	
	[[SPSession sharedSession] attemptLoginWithUserName:self.usernameField.text
											   password:self.passwordField.text
									rememberCredentials:NO];
	
	self.usernameField.enabled = NO;
	self.passwordField.enabled = NO;
	self.loginButton.enabled = NO;
	self.spinner.hidden = NO;
	
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error; {
    
	// Invoked by SPSession after a failed login.
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
													message:[error localizedDescription]
												   delegate:nil
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[[alert autorelease] show];
	
	self.usernameField.enabled = YES;
	self.passwordField.enabled = YES;
	self.loginButton.enabled = YES;
	self.spinner.hidden = YES;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
}

- (void)viewDidUnload
{
	[self setUsernameField:nil];
	[self setPasswordField:nil];
	[self setLoginButton:nil];
	[self setSpinner:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)dealloc {
	[usernameField release];
	[passwordField release];
	[loginButton release];
	[spinner release];
	[super dealloc];
}

@end
