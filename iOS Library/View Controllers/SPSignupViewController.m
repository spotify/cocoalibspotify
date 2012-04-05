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

#import "SPSignupViewController.h"
#import "SPSession.h"
#import "SPLicenseViewController.h"

@interface SPSignupViewController ()

@property (nonatomic, readwrite) NSMutableArray *jsQueue;
@property (nonatomic, readwrite, getter = isLoaded) BOOL loaded;
@property (nonatomic, readwrite, copy) NSString *currentPage;
@property (nonatomic, readwrite) SPSession *session;

-(void)loadDocument:(sp_signup_page)page stillLoading:(BOOL)isLoading recentUser:(NSString *)existingUser features:(NSUInteger)featureMask;

@end

@implementation SPSignupViewController

+(NSString *)documentNameForSignupPage:(sp_signup_page)page {

	switch (page) {
		case SP_SIGNUP_PAGE_FACEBOOK_LOGIN:
		case SP_SIGNUP_PAGE_SPOTIFY_LOGIN:
		case SP_SIGNUP_PAGE_POST_TO_OPENGRAPH_OPTION:
			return kSignupPageIntro;
			
		case SP_SIGNUP_PAGE_ENTER_CREDENTIALS:
		case SP_SIGNUP_PAGE_MERGING_ACCOUNTS:
			return kSignupPageMerge;
			
		case SP_SIGNUP_PAGE_NONE:
		case SP_SIGNUP_PAGE_DONE:
			return nil;
	}
}

-(id)initWithSession:(SPSession *)aSession {
	
	self = [super init];
	
	if (self) {
		self.session = aSession;
		self.jsQueue = [NSMutableArray array];
	}
		
	return self;
}


@synthesize jsQueue;
@synthesize loaded;
@synthesize currentPage;
@synthesize session;

-(UIWebView *)webView {
	return (UIWebView *)self.view;
}

-(void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


// Implement loadView to create a view hierarchy programmatically, without using a nib.
-(void)loadView {
	
	CGRect bounds = CGRectMake(0, 0, 320, 460);
	UIWebView *web = [[UIWebView alloc] initWithFrame:bounds];
	web.delegate = self;
	
	for(id maybeScroll in web.subviews) {
		if ([maybeScroll respondsToSelector:@selector(setBounces:)])
			((UIScrollView *)maybeScroll).bounces = NO;
	}
	
	self.view = web;
}

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

-(void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

#pragma mark Logic

-(void)runJSWhenLoaded:(NSString *)someJs {
	if (self.isLoaded)
		[self.webView stringByEvaluatingJavaScriptFromString:someJs];
	else
		[self.jsQueue addObject:someJs];
}


-(void)loadDocument:(sp_signup_page)page stillLoading:(BOOL)isLoading recentUser:(NSString *)existingUser features:(NSUInteger)featureMask {
	
	NSString *fileName = [SPSignupViewController documentNameForSignupPage:page];
	NSString *folderName = @"mobilehulkintro";

	[self loadDocument:fileName inFolder:folderName page:page stillLoading:isLoading recentUser:existingUser features:featureMask];
}

-(void)loadDocument:(NSString *)documentName inFolder:(NSString *)folderName page:(sp_signup_page)page stillLoading:(BOOL)isLoading recentUser:(NSString *)existingUser features:(NSUInteger)featureMask {
	
	NSURL *bundlePath = [[NSBundle mainBundle] URLForResource:@"SPLoginResources" withExtension:@"bundle"];
	NSBundle *resourcesBundle = [NSBundle bundleWithURL:bundlePath];

	NSURL *fileUrl = [resourcesBundle URLForResource:documentName withExtension:@"" subdirectory:folderName];
	NSURL *folderUrl = [fileUrl URLByDeletingLastPathComponent];
	
	if (![documentName isEqualToString:self.currentPage]) {
		self.loaded = NO;
		self.currentPage = documentName;
		[self.webView loadData:[NSData dataWithContentsOfURL:fileUrl]
					  MIMEType:@"text/html"
			  textEncodingName:@"utf-8"
					   baseURL:folderUrl];
	}
	
	if (isLoading) return; // Leave page in loading state
	
	if([documentName isEqual:kSignupPageIntro]) {
		
		NSString *pageToLoad = (featureMask & SP_SIGNUP_FEATURE_CONNECT_TO_FACEBOOK) ? @"existing_unsocial" :
		(featureMask & SP_SIGNUP_FEATURE_MERGE_ACCOUNT) ? @"new_hulk" :
		@"existing_social";
		
		NSString *js = [NSString stringWithFormat:@"show_page('%@')", pageToLoad];
		[self runJSWhenLoaded:js];
		
		if((featureMask & SP_SIGNUP_FEATURE_MERGE_ACCOUNT) && existingUser.length > 0)
			[self runJSWhenLoaded:[NSString stringWithFormat:@"set_existing_user('%@')", existingUser]];
		
		// TODO: Show link to licenses if that feature bit is set.
		
		// TODO: Show enable OG checkbox only if that feature bit is set.
	} else if([documentName isEqual:kSignupPageMerge]) {
		if (page == SP_SIGNUP_PAGE_MERGING_ACCOUNTS) {
			[self.webView stringByEvaluatingJavaScriptFromString:@"set_login_in_progress(true)"];
			// I have no idea what would even happen if the user cancelled a merge; let's not find out.
			self.view.window.userInteractionEnabled = NO;
		} else {
			[self.webView stringByEvaluatingJavaScriptFromString:@"set_login_in_progress(false)"];
			self.view.window.userInteractionEnabled = YES;
		}
	}
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSString *url = request.URL.absoluteString;
	if (![url hasPrefix:@"spotify:internal:"])
		return YES;
	NSString *action = [[url componentsSeparatedByString:@":"] objectAtIndex:2];
	NSString *camelAction = [[[action componentsSeparatedByString:@"-"] valueForKeyPath:@"capitalizedString"] componentsJoinedByString:@""];
    camelAction = [NSString stringWithFormat:@"%@%@", [[camelAction substringToIndex:1] lowercaseString], [camelAction substringFromIndex:1]];
	NSString *sel = [NSString stringWithFormat:@"%@:", camelAction];
	
	if ([self respondsToSelector:NSSelectorFromString(sel)]) {
		[self performSelector:NSSelectorFromString(sel) withObject:request];
		return NO;
	}
	
	return YES;
}

-(void)webView:(UIWebView*)webView didFailLoadWithError:(NSError*)error {
	if ([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        // Just ignore, this is just an async call being cancelled
        return;
    }
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
	
	for(NSString *cmd in self.jsQueue) {
		[self.webView stringByEvaluatingJavaScriptFromString:cmd];
	}
	[self.jsQueue removeAllObjects];
	self.loaded = YES;
	self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	
	[self.webView stringByEvaluatingJavaScriptFromString:
	 [NSString stringWithFormat:@"document.querySelector('meta[name=viewport]').setAttribute('content', 'width=%.0f;', false); ",
	  self.webView.frame.size.width]];
}

-(BOOL)scrobbleSettingChecked {
	return [[self.webView stringByEvaluatingJavaScriptFromString:@"get_scrobbling_setting()"] boolValue];
}


#pragma mark FeatureIntro page

-(void)connectWithFacebook:(NSURLRequest*)req {
	sp_signup_userdata_with_scrobble_setting setting;
	setting.should_scrobble = self.scrobbleSettingChecked;
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_CONNECT_TO_FACEBOOK, &setting);
}

-(void)loginSpotify:(NSURLRequest*)req {
	sp_signup_userdata_with_scrobble_setting setting;
	setting.should_scrobble = self.scrobbleSettingChecked;
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_LOGIN_WITH_SPOTIFY, &setting);
}

-(void)done:(NSURLRequest*)req {
	sp_signup_userdata_with_scrobble_setting setting;
	setting.should_scrobble = self.scrobbleSettingChecked;
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_ACCEPT, &setting);
}

-(void)dontConnect:(NSURLRequest*)req {
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_CANCEL_FACEBOOK_CONNECT, NULL);
}

-(void)readTos:(NSURLRequest*)req {
	SPLicenseViewController *agreement = [[SPLicenseViewController alloc] initWithVersion:nil];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:agreement];
	nav.navigationBar.barStyle = UIBarStyleBlack;
	nav.modalPresentationStyle = UIModalPresentationFormSheet;
 
	[self presentModalViewController:nav animated:YES];
}

#pragma mark Merge page

-(void)loginandmerge:(NSURLRequest*)req {
	
	NSString *user = [self.webView stringByEvaluatingJavaScriptFromString:@"get_username()"];
	if(!user) {
		[self.webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('username').focus()"];
		return;
	}
	NSString *pass = [self.webView stringByEvaluatingJavaScriptFromString:@"get_password()"];
	if(!pass) {
		[self.webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('password').focus()"];
		return;
	}
	
	sp_signup_userdata_with_user_credentials setting;
	setting.user_name = [user UTF8String];
	setting.password = [user UTF8String];
	sp_session_signup_perform_action(self.session.session, SP_SIGNUP_ACTION_MERGE_WITH_ACCOUNT, &setting);
}


@end
