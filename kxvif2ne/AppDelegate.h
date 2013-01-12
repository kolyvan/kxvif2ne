//
//  AppDelegate.h
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
- (void) openURLInWebBrowserController: (NSURL *) url;

@end
