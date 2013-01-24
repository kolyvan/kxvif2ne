//
//  BaseVifViewController.h
//  kxvif2ne
//
//  Created by Kolyvan on 11.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <UIKit/UIKit.h>
#import "KxTableViewController.h"

@class PostViewController;
@class VifArticle;
@class CKRefreshControl;

@interface BaseVifViewController : KxTableViewController<UIPopoverControllerDelegate>

@property (nonatomic,retain) UIRefreshControl *refreshControl;
@property (readonly, nonatomic, strong) UIPopoverController *loginPopoverController;
@property (readonly, nonatomic, strong) PostViewController  *postViewController;
@property (readonly, nonatomic) CGFloat cellWidth;

- (BOOL) openArticle: (NSUInteger) number;
- (void) didTouchPostMessage;
- (void) postMessage: (VifArticle *) article;
- (void) doRefresh: (id)sender;

@end
