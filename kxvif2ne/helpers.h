//
//  helpers.h
//  kxvif2ne
//
//  Created by Kolyvan on 29.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

extern NSString *fixAmpersandsInString(NSString *string);
extern NSString *fixBrokenURLInHTML(NSString *html);
extern NSData *fixBrokenTitleInXML(NSData *xml) __attribute__((deprecated));
extern void drainCacheIfExcess(NSMutableDictionary *cache, NSUInteger maxSize);
extern NSString *stripHTMLComment(NSString *html);
extern NSString *stripHTMLTags(NSString *html);
extern NSUInteger parseIntegerValueFromHex(NSString *hex);