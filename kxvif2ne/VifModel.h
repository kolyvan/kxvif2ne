//
//  VifModel.h
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

extern NSString *vifModelErrorDomain;

typedef enum {
    
    VifModelErrorNone,
    VifModelErrorNetworkFailure,
    VifModelErrorHTTPFailure,
    VifModelErrorWrongXMLResponse,
    VifModelErrorUnableParseArticle,
    VifModelErrorUnableParseLastEvent,
    
} VifModelError;

extern NSError *vifModelError(VifModelError error, NSString *format, ...);
 
@interface VifArticle : NSObject<NSCoding>
@property (readonly, nonatomic) NSUInteger number;
@property (readonly, nonatomic) NSUInteger parent;
@property (readonly, nonatomic) NSUInteger size;
@property (readonly, nonatomic, strong) NSDate *date;
@property (readonly, nonatomic, strong) NSString *author;
@property (readonly, nonatomic, strong) NSString *title;
@property (readonly, nonatomic) BOOL fixed;

@end


@class VifTree;

@interface VifNode : NSObject
@property (readonly, nonatomic, weak) VifNode *parent;
@property (readonly, nonatomic, strong) VifTree *tree;
@property (readonly, nonatomic, strong) VifArticle *article;
@property (readonly, nonatomic, strong) NSDate *date;

- (BOOL) isRecent;
- (BOOL) isUnread;
- (void) clearUnread;

@end

@interface VifTree : NSObject
@property (readonly, nonatomic, strong) NSArray *nodes;
@property (readonly, nonatomic, strong) NSDate *date;

- (VifNode *) findNode: (NSUInteger) number;

- (NSUInteger) numReplies;
- (NSUInteger) numRecent;
- (BOOL) hasUnread;

- (NSArray *) sortedNodes;
- (NSArray *) deepSortedNodes;

@end


typedef void(^VifModelBlock)(id result);

@class VifMessageCache;

@interface VifModel : VifTree

@property (readonly, nonatomic, strong) NSDate *prevDate;
@property (readonly, nonatomic, strong) VifMessageCache *messageCache;

+ (VifModel *) model;

- (void) asyncUpdate: (VifModelBlock) block;

- (void) cancelAll;

- (void) save: (NSString *) path;
- (void) load: (NSString *) path;

- (BOOL) isDirty;

- (void) postMessage: (NSUInteger) articleNumber
             subject: (NSString *) subject
                body: (NSString *) body;

@end
