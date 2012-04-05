//
//  SPLicenseViewControllerViewController.m
//  CocoaLibSpotify iOS Library
//
//  Created by Daniel Kennett on 26/03/2012.
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

#import "SPLicenseViewController.h"
#import <QuartzCore/QuartzCore.h>

static NSString * const kSPLicensesNoVersionURL = @"http://www.spotify.com/mobile/end-user-agreement/?notoken";
static NSString * const kSPLicensesFormatter = @"http://www.spotify.com/mobile/end-user-agreement/?notoken&version=%@";

@interface SPLicenseViewController ()

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, readwrite, copy) NSString *version;

@end

@implementation SPLicenseViewController

-(id)initWithVersion:(NSString *)licenseVersion {
	
	self = [super init];
	
	if (self) {
		self.version = licenseVersion;
	}
	return self;
}


@synthesize spinner;
@synthesize version;

-(void)done {
	
	UIViewController *parent = self.navigationController;
	
	if ([parent respondsToSelector:@selector(presentingViewController)]) {
		[parent.presentingViewController dismissModalViewControllerAnimated:YES];
	} else {
		[parent.parentViewController dismissModalViewControllerAnimated:YES];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(UIWebView *)webView {
	return (UIWebView *)self.view;
}

-(void)loadView {
	
	self.title = @"T&Cs and Privacy Policy";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
																							target:self
																							action:@selector(done)];
	CGRect bounds = CGRectMake(0, 0, 320, 460);
	UIWebView *web = [[UIWebView alloc] initWithFrame:bounds];
	web.delegate = self;
	
	NSURL *licenseUrl = nil;
	
	if (self.version.length == 0)
		licenseUrl = [NSURL URLWithString:kSPLicensesNoVersionURL];
	else 
		licenseUrl = [NSURL URLWithString:[NSString stringWithFormat:kSPLicensesFormatter, self.version]];
	
	[web loadRequest:[NSURLRequest requestWithURL:licenseUrl]];
	
	for(id maybeScroll in web.subviews) {
		if ([maybeScroll respondsToSelector:@selector(setBounces:)])
			((UIScrollView *)maybeScroll).bounces = NO;
	}
	
	self.view = web;
	
	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];
	
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	self.spinner.layer.position = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
	[self.spinner startAnimating];
}

-(void)viewDidUnload {
	self.spinner = nil;
	[super viewDidUnload];
}

#pragma mark - WebView

-(void)webView:(UIWebView*)webView didFailLoadWithError:(NSError*)error {
	if ([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        // Just ignore, this is just an async call being cancelled
        return;
    }

	// Show error page if license didn't load

	NSURL *bundlePath = [[NSBundle mainBundle] URLForResource:@"SPLoginResources" withExtension:@"bundle"];
	NSBundle *resourcesBundle = [NSBundle bundleWithURL:bundlePath];
	
	NSURL *fileUrl = [resourcesBundle URLForResource:@"toc_error" withExtension:@"xhtml" subdirectory:nil];
	NSURL *folderUrl = [fileUrl URLByDeletingLastPathComponent];
	
	NSData *fileData = [NSData dataWithContentsOfURL:fileUrl];
	[webView loadData:fileData MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:folderUrl];
}

-(void)webViewDidStartLoad:(UIWebView *)webView {
	[self.spinner startAnimating];
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
	[self.spinner stopAnimating];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:[request URL]];
		return NO;
	}
	return YES;
}

@end
