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
#import "SPLoginLogicViewController.h"
#import "SPFacebookPermissionsViewController.h"
#import "SPLicenseViewController.h"
#import "SPLoginViewControllerInternal.h"

@interface SPLoginViewController ()

-(id)initWithSession:(SPSession *)aSession;
-(void)showIfNeeded;

@property (nonatomic, readwrite, getter = isShown) BOOL shown;
@property (nonatomic, readwrite) SPSession *session;
@property (nonatomic, readwrite) BOOL didReceiveSignupFlow;

@property (nonatomic, readwrite) BOOL waitingForFacebookPermissions;

@end

@implementation SPLoginViewController

static NSMutableDictionary *loginControllerCache;

+(SPLoginViewController *)loginControllerForSession:(SPSession *)session {
	
	if (session == nil) return nil;
	
	if (!loginControllerCache)
		loginControllerCache = [[NSMutableDictionary alloc] init];
		
	NSValue *ptrValue = [NSValue valueWithPointer:(const void *)session];
	
	SPLoginViewController *controller = [loginControllerCache objectForKey:ptrValue];
	
	if (controller == nil) {
		controller = [[SPLoginViewController alloc] initWithSession:session];
		[loginControllerCache setObject:controller forKey:ptrValue];
	}
	
	return controller;
}

-(id)initWithSession:(SPSession *)aSession {
	
	self = [super initWithRootViewController:[[SPLoginLogicViewController alloc] initWithSession:aSession]];
	
	if (self) {
		self.session = aSession;
		self.navigationBar.barStyle = UIBarStyleBlack;
		self.modalPresentationStyle = UIModalPresentationFormSheet;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(sessionDidLogin:)
													 name:SPSessionLoginDidSucceedNotification
												   object:self.session];
		
	}
	return self;
}

-(void)dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:SPSessionLoginDidSucceedNotification
												  object:self.session];
	
}

#pragma mark -

@synthesize shown;
@synthesize didReceiveSignupFlow;
@synthesize session;
@synthesize waitingForFacebookPermissions;
@synthesize loginDelegate;


-(void)setAllowsCancel:(BOOL)allowsCancel {
	SPLoginLogicViewController *root = [[self viewControllers] objectAtIndex:0];
	root.allowsCancel = allowsCancel;
}

-(BOOL)allowsCancel {
	SPLoginLogicViewController *root = [[self viewControllers] objectAtIndex:0];
	return root.allowsCancel;
}

-(void)sessionDidLogin:(NSNotification *)notification {
	
	int num_licenses = sp_session_signup_get_unaccepted_licenses(self.session.session, NULL, 0);
	
	if (num_licenses > 0) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"T&C and Privacy Policy"
														 message:@"I have read and accept Spotify's Terms and Conditions of Use and Privacy Policy."
														delegate:self
											   cancelButtonTitle:@"Show terms"
											   otherButtonTitles:@"Accept", nil];
		[alert show];
	}
	
	if ((!self.didReceiveSignupFlow) && num_licenses == 0) {
		[self dismissLoginView:YES];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == [alertView cancelButtonIndex]) {
		// Show T&Cs
		
		[self handleShowSignupPage:SP_SIGNUP_PAGE_NONE loading:NO featureMask:0 recentUserName:nil];
		
		int num_licenses = sp_session_signup_get_unaccepted_licenses(self.session.session, NULL, 0);
		const char **licenses = malloc(sizeof(const char *) * num_licenses);
		num_licenses = sp_session_signup_get_unaccepted_licenses(self.session.session, licenses, num_licenses);
		
		NSString *licenseToView = nil;
		if (num_licenses > 0)
			licenseToView = [NSString stringWithUTF8String:licenses[num_licenses-1]];
		
		free(licenses);
		
		SPLicenseViewController *agreement = [[SPLicenseViewController alloc] initWithVersion:licenseToView];
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:agreement];
		nav.navigationBar.barStyle = UIBarStyleBlack;
		nav.modalPresentationStyle = UIModalPresentationFormSheet;
		
		[self presentModalViewController:nav animated:YES];
		
	} else {
		//Success!
		const char **licenses = malloc(sizeof(char *) * 10);
		int num_licenses = sp_session_signup_get_unaccepted_licenses(self.session.session, licenses, 10);
		sp_signup_userdata_with_accepted_licenses licenses_info;
		licenses_info.licenses = licenses;
		licenses_info.license_count = num_licenses;
		sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_ACCEPT_LICENSES, &licenses_info);
		free(licenses);
		
		if (!self.didReceiveSignupFlow)
			[self dismissLoginView:YES];
	}
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
		return YES;
	else
		return interfaceOrientation == UIInterfaceOrientationPortrait;
}

# pragma mark - Logic

-(void)signupPageDidCancel:(id)page {
	[self handleShowSignupPage:SP_SIGNUP_PAGE_NONE loading:NO featureMask:0 recentUserName:nil];
}

-(void)signupPageDidAccept:(id)page {
	if ([page isKindOfClass:[SPFacebookPermissionsViewController class]]) {
		// Facebook is always last!
		[self dismissLoginView:YES];
	}
}

-(void)signupDidPushBack {
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_GO_BACK, NULL);
}

-(void)signupDidPushCancel {
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_CANCEL_SIGNUP, NULL);
	[self handleShowSignupPage:SP_SIGNUP_PAGE_NONE loading:NO featureMask:0 recentUserName:nil];
}

-(void)viewDidAppear:(BOOL)animated {
	self.shown = YES;
}

-(void)viewWillDisappear:(BOOL)animated {
	self.shown = NO;
}

-(void)viewDidDisappear:(BOOL)animated {
	// Since we're a shared instance reset state
	SPLoginLogicViewController *root = [[self viewControllers] objectAtIndex:0];
	[root resetState];
	[self popToViewController:root animated:NO];
}

-(void)showIfNeeded {
	
	if (self.isShown) return;
	
	UIViewController *parent = nil;
	
	if ([self.session.delegate respondsToSelector:@selector(viewControllerToPresentLoginViewForSession:)])
		parent = [self.session.delegate viewControllerToPresentLoginViewForSession:self.session];
	
	if (parent == nil)
		parent = [UIApplication sharedApplication].keyWindow.rootViewController;
	
	if (parent == nil) {
		UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
		for (UIView *view in mainWindow.subviews) {
			UIResponder *nextResponder = view.nextResponder;
			if ([nextResponder isKindOfClass:[UIViewController class]])
				parent = (UIViewController *)nextResponder;
			
			if (parent)
				break;
		}
	}
	
	if (parent == nil)
		return;
	
	[parent presentModalViewController:self animated:NO];
}

@end

@implementation SPLoginViewController (SPLoginViewControllerInternal)

-(void)dismissLoginView:(BOOL)success {
	if ([self respondsToSelector:@selector(presentingViewController)]) {
		[self.presentingViewController dismissModalViewControllerAnimated:YES];
	} else {
		[self.parentViewController dismissModalViewControllerAnimated:YES];
	}
	
	[self.loginDelegate loginViewController:self didCompleteSuccessfully:success];
}

-(void)handleShowSignupPage:(sp_signup_page)page loading:(BOOL)isLoading featureMask:(NSInteger)features recentUserName:(NSString *)name {
	
	if (page == SP_SIGNUP_PAGE_DONE) {
		if (self.isShown && !self.waitingForFacebookPermissions) {
			[self dismissModalViewControllerAnimated:YES];
		}
		self.didReceiveSignupFlow = NO;
		return;
	}
	
	if (page == SP_SIGNUP_PAGE_NONE) {
		[self.session logout];
		SPLoginLogicViewController *root = [[self viewControllers] objectAtIndex:0];
		[root resetState];
		[self popToViewController:root animated:YES];
		return;
	}
	
	[self showIfNeeded];
	self.didReceiveSignupFlow = YES;
	
	NSString *documentName = [SPSignupViewController documentNameForSignupPage:page];
	
	// Figure out if it's the one we're currently showing; if not, make sure we do.
	NSString *topname = [(SPSignupViewController *)[self topViewController] currentPage];
	SPSignupViewController *viewController = nil;
	
	if(![topname isEqual:documentName]) {
		NSUInteger i = [[[self viewControllers] valueForKeyPath:@"currentPage"] indexOfObject:documentName];
		if(i != NSNotFound) {
			viewController = [[self viewControllers] objectAtIndex:i];
			if ([viewController respondsToSelector:@selector(loadDocument:stillLoading:recentUser:features:)])
				[viewController loadDocument:page stillLoading:isLoading recentUser:name features:features];
			[self popToViewController:viewController animated:YES];
		} else {
			viewController = [[SPSignupViewController alloc] initWithSession:self.session];
			[viewController loadDocument:page stillLoading:isLoading recentUser:name features:features];
			
			[self pushViewController:viewController animated:YES];
			
			SEL action = (self.viewControllers.count == 2) ? @selector(signupDidPushCancel) : @selector(signupDidPushBack);
			viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:action];
		}
	} else if ([[self topViewController] respondsToSelector:@selector(loadDocument:stillLoading:recentUser:features:)]) {
		[(id)[self topViewController] loadDocument:page stillLoading:isLoading recentUser:name features:features];
	}
}

-(void)handleShowSignupErrorPage:(sp_signup_page)page error:(NSError *)error {
	
	[self handleShowSignupPage:page loading:NO featureMask:0 recentUserName:nil];
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Account Merge Failed"
													message:@"Sorry, but we couldn't connect your Spotify account with Facebook. Please try again."
												   delegate:nil
										  cancelButtonTitle:@"OK" otherButtonTitles:nil];
	
	[alert show];
}

-(void)handleConnectToFacebookWithPermissions:(NSArray *)permissions {
	
	BOOL alreadyShowing = self.isShown;
	[self showIfNeeded];
	
	self.waitingForFacebookPermissions = YES;
	
	SPFacebookPermissionsViewController *controller = [[SPFacebookPermissionsViewController alloc] initWithPermissions:permissions
																											 inSession:self.session];
	controller.delegate = self;
	
	[self pushViewController:controller animated:alreadyShowing];
}


@end
