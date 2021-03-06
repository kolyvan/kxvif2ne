//
//  PostViewController.h
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
#import "VifModel.h"

//@class VifArticle;

@interface PostViewController : UIViewController<UITextViewDelegate>
@property (readwrite, nonatomic, strong) VifArticle *article;
@property (readwrite, nonatomic, strong) VifModelBlock didSendBlock;

@end
