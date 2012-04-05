//
//  Guess_The_IntroAppDelegate.h
//  Guess The Intro
//
//  Created by Daniel Kennett on 10/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Guess_The_IntroViewController;

@interface Guess_The_IntroAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;

@property (nonatomic, strong) IBOutlet Guess_The_IntroViewController *viewController;

@end
