//
//  ImageLoader.h
//  kxvif2ne
//
//  Created by Kolyvan on 08.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

@interface ImageLoader : NSObject

+ (id) imageLoader;

- (void) asyncLoadImages: (NSArray *) sources
               completed: (BOOL(^)(UIImage *image, NSString *source)) completed;

@end
