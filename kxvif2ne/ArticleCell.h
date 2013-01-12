//
//  ArticleCell.h
//  kxvif2ne
//
//  Created by Kolyvan on 27.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <UIKit/UIKit.h>
#import "FastCell.h"

@class VifNode;
@class KxHTMLRender;

@interface VifNodeCell : FastCell

@property (readwrite, nonatomic, strong) VifNode *node;
@property (readwrite, nonatomic, strong) NSString *text;
@property (readwrite, nonatomic, strong) KxHTMLRender *htmlRender;

+ (CGFloat) heightForNode:(VifNode *) node
                     text:(NSString *)text
               htmlRender:(KxHTMLRender *)htmlRender
                withWidth:(CGFloat) width;

- (BOOL) handleTouch: (CGPoint) pt;

@end
