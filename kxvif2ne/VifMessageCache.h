//
//  VifMessageCache.h
//  kxvif2ne
//
//  Created by Kolyvan on 09.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

typedef void(^VifMessageCacheBlock)(NSUInteger number, id result);

@interface VifMessageCache : NSObject

- (BOOL) containsMessage:(NSUInteger) articleNumber;

- (id) lookupMessage:(NSUInteger) articleNumber;

- (void) fetchMessage:(NSUInteger) articleNumber
                block:(VifMessageCacheBlock) block;

- (void) removeMessage:(NSUInteger) articleNumber;

- (void) reset;

- (void) cancelAll;

@end