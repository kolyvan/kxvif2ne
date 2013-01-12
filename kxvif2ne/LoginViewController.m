//
//  LoginViewController.m
//  kxvif2ne
//
//  Created by Kolyvan on 10.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "LoginViewController.h"
#import "ColorTheme.h"
#import "VifSettings.h"
#import "HTTPRequest.h"

@interface LoginViewController ()
@end

@implementation LoginViewController {
    
    UITextField *_loginField;
    UITextField *_passField;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
    }
    return self;
}

- (void) loadView
{
    ColorTheme *theme = [ColorTheme theme];
        
    const CGFloat W = 280;
    const CGFloat H = 151;
    
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    self.view.backgroundColor = theme.backgroundColor;
    
    self.contentSizeForViewInPopover = CGSizeMake(W, H);
    
    UILabel *titleLabel;
    titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,10,W-20,30)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = theme.alertColor;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.text = NSLocalizedString(@"Authorization required", nil);
    
    [self.view addSubview:titleLabel];
    
    UILabel *loginLabel;
    loginLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,50,90,30)];
    loginLabel.backgroundColor = [UIColor clearColor];
    loginLabel.textColor = theme.textColor;
    loginLabel.font = [UIFont boldSystemFontOfSize:16];
    loginLabel.text = NSLocalizedString(@"Username", nil);
    
    [self.view addSubview:loginLabel];
    
    UILabel *passLabel;
    passLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,100,90,30)];
    passLabel.backgroundColor = [UIColor clearColor];
    passLabel.textColor = theme.textColor;
    passLabel.font = [UIFont boldSystemFontOfSize:16];    
    passLabel.text = NSLocalizedString(@"Password", nil);
    
    [self.view addSubview:passLabel];
    
    _loginField = [[UITextField alloc] initWithFrame:CGRectMake(100, 51, W - 110, 30)];
    _loginField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _loginField.autocorrectionType = UITextAutocorrectionTypeNo;
    _loginField.spellCheckingType = UITextSpellCheckingTypeNo;
    _loginField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _loginField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    _loginField.textColor = theme.highlightTextColor;
    _loginField.font = [UIFont systemFontOfSize:16];
    _loginField.borderStyle = UITextBorderStyleRoundedRect;
    _loginField.backgroundColor = theme.tintColor;
    _loginField.returnKeyType = UIReturnKeyNext;
    
    [_loginField addTarget:self
                    action:@selector(textFieldDoneEditing:)
          forControlEvents:UIControlEventEditingDidEndOnExit];
        
    [self.view addSubview:_loginField];
    
    _passField = [[UITextField alloc] initWithFrame:CGRectMake(100, 101, W - 110, 30)];
    _passField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _passField.autocorrectionType = UITextAutocorrectionTypeNo;
    _passField.spellCheckingType = UITextSpellCheckingTypeNo;
    _passField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _passField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    _passField.textColor = theme.highlightTextColor;
    _passField.secureTextEntry = YES;
    _passField.font = [UIFont systemFontOfSize:16];
    _passField.borderStyle = UITextBorderStyleRoundedRect;
    _passField.backgroundColor = theme.tintColor;
    _passField.returnKeyType = UIReturnKeyDone;
    
    [_passField addTarget:self
                   action:@selector(textFieldDoneEditing:)
         forControlEvents:UIControlEventEditingDidEndOnExit];
    
    [self.view addSubview:_passField];    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _loginField.text = [[VifSettings settings] loginName];
    [_loginField becomeFirstResponder];
}

- (void) textFieldDoneEditing: (id) sender
{
    if (sender == _loginField) {
        
        [_passField becomeFirstResponder];
        
    } else {
        
        VifSettings *settings = [VifSettings settings];
        
        if (_loginField.text.length && _passField.text.length) {
        
            // login
            
            [settings login:_loginField.text.lowercaseString
                   password:_passField.text.lowercaseString];
            
            [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
            
            [HTTPRequest httpGet:[NSURL URLWithString:@"http://www.vif2ne.ru/nvk/forum/0/security/"]
                         referer:nil
                   authorization:[[VifSettings settings] authorization]
                        response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res)
             {
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                 
                 NSString *message;
                 
                 if (res.statusCode == 200) {
                     
                     message = NSLocalizedString(@"Login Success", nil);
                     
                 } else {
                     
                     settings.authorization = nil;
                     
                     if (res.statusCode == 401) {
                         
                         message = NSLocalizedString(@"Not Authorized", nil);
                         
                     } else {
                         
                         message = [NSHTTPURLResponse localizedStringForStatusCode: res.statusCode];
                         message = [NSString stringWithFormat:@"%d %@", res.statusCode, message];
                     }
                 }
                 
                 [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                             message:message
                                            delegate:nil
                                   cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                   otherButtonTitles:nil] show];
                 
                 return NO;
             }
                        progress:nil
                        complete:nil];
            
        }
        
        [self hideMe];
    }
}

- (void) hideMe
{
    if (self.navigationController) {
        
        [self.navigationController popViewControllerAnimated:YES];
        
    } else if ([self.parentViewController isKindOfClass:[UINavigationController class]]) {
        
        [(UINavigationController *)self.parentViewController popViewControllerAnimated:YES];
        
    } else {
        
        __strong id p = self.delegate;
        if (p && [p respondsToSelector:@selector(couldDismissLoginViewController:)]) {
            
            [p couldDismissLoginViewController: self];
        }
    }
}

@end
