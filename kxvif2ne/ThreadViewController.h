//
//  ThreadViewController.h
//  kxvif2ne
//
//  Created by Kolyvan on 07.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <UIKit/UIKit.h>
#import "BaseVifViewController.h"
#import "KxHTML.h"

@class VifNode;

@interface ThreadViewController : BaseVifViewController<KxHTMLRenderDelegate>
@property (readwrite, nonatomic, strong) VifNode* rootNode;
@property (readwrite, nonatomic) BOOL plainMode;
@end

