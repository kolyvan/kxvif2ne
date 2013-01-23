//
//  BaseVifViewController.m
//  kxvif2ne
//
//  Created by Kolyvan on 11.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "BaseVifViewController.h"
#import "VifModel.h"
#import "VifSettings.h"
#import "LoginViewController.h"
#import "PostViewController.h"
#import "CKRefreshControl.h"

@interface BaseVifViewController ()
@end

@implementation BaseVifViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        
        self.title = @"VIF2NE.RU";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                       target:self
                                                                       action:@selector(didTouchPostMessage)];
    self.navigationItem.rightBarButtonItem = b;
        
    CKRefreshControl *refreshControl = [CKRefreshControl new];
    [refreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = (id)refreshControl;
    [self.tableView addSubview:refreshControl];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    _loginPopoverController = nil;
    _postViewController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_cellWidth) {
        const CGFloat cellMargin = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? 10 : 45;
        _cellWidth = self.tableView.frame.size.width - cellMargin * 2;
    }
}

- (BOOL) openArticle: (NSUInteger) number
{
    NSAssert(false, @"abstract method");
    return NO;
}

- (void) didTouchPostMessage
{
    [self postMessage: nil];
}

- (void) postMessage: (VifArticle *) article;
{
    VifSettings *settings = [VifSettings settings];
    if (settings.authorization) {
        
        if (!_postViewController)
            _postViewController = [[PostViewController alloc] init];
        _postViewController.article = article;
        [self.navigationController pushViewController:_postViewController animated:YES];
        
    } else {
        
        LoginViewController *vc = [[LoginViewController alloc] init];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            
            [self.navigationController pushViewController:vc animated:YES];
            
        } else {
            
            if (_loginPopoverController) {
                
                _loginPopoverController.delegate = nil;
                [_loginPopoverController dismissPopoverAnimated:YES];
                _loginPopoverController = nil;
                
            } else {
                
                _loginPopoverController = [[UIPopoverController alloc] initWithContentViewController: vc];
                _loginPopoverController.delegate = self;
                vc.delegate = self;
                [_loginPopoverController presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem
                                                permittedArrowDirections:UIPopoverArrowDirectionAny
                                                                animated:YES];
            }            
        }
    }
}

- (void)doRefresh:(CKRefreshControl *)sender
{
}

#pragma mark - PopOver controler delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    _loginPopoverController = nil;
}

- (void) couldDismissLoginViewController: (LoginViewController *) controller
{
    controller.delegate = nil;
    _loginPopoverController.delegate = nil;
    [_loginPopoverController dismissPopoverAnimated:YES];
    _loginPopoverController = nil;
}

@end
