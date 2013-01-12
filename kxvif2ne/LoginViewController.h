//
//  LoginViewController.h
//  kxvif2ne
//
//  Created by Kolyvan on 10.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <UIKit/UIKit.h>

@class LoginViewController;

@protocol LoginViewControllerDelegate
@optional
- (void) couldDismissLoginViewController: (LoginViewController *) controller;
@end

@interface LoginViewController : UIViewController
@property (readwrite, nonatomic, weak) id delegate;
@end
