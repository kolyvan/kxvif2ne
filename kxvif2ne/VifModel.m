//
//  VifModel.m
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "VifModel.h"
#import "VifMessageCache.h"
#import "VifSettings.h"
#import "XmlReader.h"
#import "HTTPRequest.h"
#import "NSDate+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "KxUtils.h"
#import "DDLog.h"
#import "helpers.h"

static int ddLogLevel = LOG_LEVEL_INFO;


NSString * vifModelErrorDomain = @"ru.kolyvan.vifmodel";

static NSString * vifModelErrorStringForCode(VifModelError error)
{
    switch (error) {
        case VifModelErrorNetworkFailure: return NSLocalizedString(@"Network failure", nil);
        case VifModelErrorHTTPFailure: return NSLocalizedString(@"HTTP failure", nil);
        case VifModelErrorWrongXMLResponse: return NSLocalizedString(@"Wrong XML response", nil);
        case VifModelErrorUnableParseArticle: return NSLocalizedString(@"Unable parse article", nil);
        case VifModelErrorUnableParseLastEvent: return NSLocalizedString(@"Unable parse lastEvent", nil);
        default: return NSLocalizedString(@"Unknown failure", nil);
    }
}

NSError * vifModelError (VifModelError error, NSString *format, ...)
{
    NSDictionary *userInfo = nil;
    
    if (format) {
        
        va_list args;
        va_start(args, format);
        NSString *reason = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        userInfo = @{
            NSLocalizedDescriptionKey : vifModelErrorStringForCode(error),
            NSLocalizedFailureReasonErrorKey : reason
        };
        
    } else {
        
        userInfo = @{ NSLocalizedDescriptionKey : vifModelErrorStringForCode(error) };
    }
    
    DDLogCWarn(@"VifModelError %@", userInfo);
    
    return [NSError errorWithDomain:vifModelErrorDomain
                               code:error
                           userInfo:userInfo];
}

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface VifArticle()
@property (readwrite, nonatomic) NSUInteger parent;
@property (readwrite, nonatomic) BOOL fixed;
@end

@implementation VifArticle

- (id) initFromDictionary: (NSDictionary *) dict
{
    NSAssert(dict.count, @"empty dict");
    
    self = [super init];
    if (self) {
        
        static NSTimeZone * mskTZ;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            mskTZ = [NSTimeZone timeZoneWithAbbreviation:@"MSK"];
        });
        
        _number = parseIntegerValueFromHex(dict[@"no"]);
        _parent = parseIntegerValueFromHex(dict[@"parent"]);
        _size = [dict[@"size"] integerValue];
        _date = [NSDate date: dict[@"date"]
                      format:@"dd.MM.yyyy HH:mm:ss"
                      locale:nil
                    timeZone:mskTZ];

        _author = dict[@"author"];
        _title = dict[@"title"];
        
        _title = _title.trimmed;
        
        if ([_title hasSuffix:@"(-)"] ||
            [_title hasSuffix:@"(+)"]) {
            
            _title = [_title substringToIndex:_title.length - 3];
        }
        
        NSAssert(_number, @"zero number");
        NSAssert(_date, @"nil date");
        NSAssert(_author.length, @"empty author");
        NSAssert(_title.length, @"empty title");
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<art #%d->%d %@ '%@' %d> ", _number, _parent, _author, _title, _size];
}

#pragma mark - NSCoding

- (id) initWithCoder: (NSCoder*)coder
{
   	if ([coder versionForClassName: NSStringFromClass(self.class)] != 0)
	{
		self = nil;
		return nil;
	}
    
    if ([coder allowsKeyedCoding])
	{
		_number = [coder decodeIntegerForKey: @"number"];
		_parent = [coder decodeIntegerForKey: @"parent"];
        _size   = [coder decodeIntegerForKey: @"size"];
		_date   = [coder decodeObjectForKey: @"date"];
        _author = [coder decodeObjectForKey: @"author"];
        _title  = [coder decodeObjectForKey: @"title"];
        _fixed  = [coder decodeBoolForKey: @"fixed"];
	}
	else
	{
        _number = [[coder decodeObject] integerValue];
		_parent = [[coder decodeObject] integerValue];
        _size   = [[coder decodeObject] integerValue];
		_date   = [coder decodeObject];
        _author = [coder decodeObject];
        _title  = [coder decodeObject];
        _fixed = [[coder decodeObject] boolValue];
	}
    
    return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
    if ([coder allowsKeyedCoding])
	{
        [coder encodeInteger:_number forKey:@"number"];
        [coder encodeInteger:_parent forKey:@"parent"];
        [coder encodeInteger:_size   forKey:@"size"];
        [coder encodeObject:_date    forKey:@"date"];
        [coder encodeObject:_author  forKey:@"author"];
        [coder encodeObject:_title   forKey:@"title"];
        [coder encodeBool:_fixed     forKey:@"fixed"];
	}
	else
	{
        [coder encodeObject:@(_number)];
        [coder encodeObject:@(_parent)];
        [coder encodeObject:@(_size)];
        [coder encodeObject:_date];
        [coder encodeObject:_author];
        [coder encodeObject:_title];
        [coder encodeObject:@(_fixed)];
    }
}

@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface VifTree()
- (void) resetCounters;
@end

@implementation VifNode {
    
   NSInteger _unread;
}

@dynamic date;

- (NSDate *) date
{
    return _tree.nodes.count ? _tree.date : _article.date;
}

- (id) init: (VifNode *)parent
    article: (VifArticle *)article
{
    NSAssert(article, @"nil article");
    
    self = [super init];
    if (self) {
        
        _parent = parent;
        _article = article;
        _tree = [[VifTree alloc] init];
        
        _unread = -1;
    }
    return self;
}

- (BOOL) isRecent
{
    if ([[VifModel model].prevDate isLess:_article.date])
        return [self isUnread];
    return NO;
}

- (BOOL) isUnread
{
    if (_unread < 0)
        _unread = ![[VifModel model].messageCache containsMessage: _article.number];
    return _unread != 0;
}

- (void) clearUnread
{
    _unread = NO;
    [self resetCountersUpward];
}

- (void) resetCountersUpward
{
    __strong VifNode *parent = self.parent;
    if (parent) {
        
        [parent.tree resetCounters];
        [parent resetCountersUpward];
    }
}

@end

@implementation VifTree {
    
    NSMutableArray  *_nodes;
    NSInteger      _numReplies;
    NSInteger      _numRecent;
    NSInteger      _hasUnread;
}

@dynamic nodes;

- (NSArray *) nodes
{
    return _nodes;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        _nodes = [NSMutableArray array];
        [self resetCounters];
    }
    return self;
}

- (VifNode *) findNode: (NSUInteger) number
{
    for (VifNode *node in _nodes) {
        
        if (node.article.number == number)
            return node;
            
        VifNode* p = [node.tree findNode:number];
        if (p)
            return p;
    }
    
    return nil;
}

- (void) addNode: (VifNode *) node
{
    _date = _date ? [node.article.date laterDate: _date] : node.article.date;    
    [_nodes addObject:node];
}

- (VifNode *) addArticle: (VifArticle *) article
{
    VifNode *result = nil;
    
    for (VifNode *node in _nodes) {
        
        if (node.article.number == article.parent) {
            
            result = [[VifNode alloc] init:node article:article];
            [node.tree addNode:result];
            break;
        }
        
        result = [node.tree addArticle:article];
        if (result)
            break;
    }
    
    if (result) {
        _date = _date ? [article.date laterDate: _date] : article.date;
    }
    
    return result;
}

- (BOOL) delArticle: (NSUInteger) number
{
    BOOL result = NO;
    
    for (VifNode *node in _nodes) {
        
        if (node.article.number == number) {
            
            DDLogVerbose(@"deleted %@", node.article);
            
            [_nodes removeObject:node];
            result = YES;
            break;
        }
        
        if ([node.tree delArticle:number]) {
            
            result = YES;
            break;
        }
    }
        
    return result;
}

- (void) collectArticles: (NSMutableArray *) result
{
    for (VifNode *node in _nodes) {
        
        [result addObject:node.article];
        [node.tree collectArticles:result];
    }
}

- (void) collectSortedNodes: (NSMutableArray *) result
{
    for (VifNode *node in self.sortedNodes) {
        
        [result addObject:node];
        [node.tree collectSortedNodes:result];
    }
}

- (void) dump: (NSUInteger) indent
{
    for (VifNode *node in _nodes) {
         
        printf("%*s %s / %d %d\n",
               indent, "", node.article.description.UTF8String, node.tree->_numReplies, node.tree->_numRecent);
        
        [node.tree dump:indent+1];
    }
}

- (NSUInteger) numReplies
{
    if (_numReplies < 0) {
        _numReplies = _nodes.count;
        for (VifNode *node in _nodes)
            _numReplies += node.tree.numReplies;
    }
    return _numReplies;
}

- (NSUInteger) numRecent
{
    if (_numRecent < 0) {
        _numRecent = 0;
        for (VifNode *node in _nodes) {
            
            if (node.isRecent)
                _numRecent++;
            _numRecent += node.tree.numRecent;
        }
    }
    return _numRecent;
}

- (BOOL) hasUnread
{
    if (_hasUnread < 0) {
        
        _hasUnread = NO;
        for (VifNode *node in _nodes) {
            if (node.isUnread ||
                node.tree.hasUnread) {
                _hasUnread = YES;
                break;
            }
        }
    }
    return _hasUnread;
}

- (void) reset
{
    [_nodes removeAllObjects];
    [self resetCounters];
}

- (void) resetCounters
{
    _numReplies =  _numRecent = _hasUnread = -1;
}

- (void) resetCountersRecursively
{
    [self resetCounters];
    for (VifNode *node in _nodes)
        [node.tree resetCountersRecursively];
}

- (NSArray *) sortedNodes
{
    return [_nodes sortedArrayUsingComparator:^(VifNode *left, VifNode *right) {
        
        return [right.date compare:left.date];
    }];
}

- (NSArray *) deepSortedNodes
{
    NSMutableArray *ma = [ NSMutableArray array];
    [self collectSortedNodes:ma];
    return ma;
}

/*
- (void) assertCounters
{
    NSAssert(_numRecent == -1, @"invalid numRecent");
    NSAssert(_numRecent == -1, @"invalid numRecent");
    NSAssert(_hasUnread == -1, @"invalid hasUnread");
    
    for (VifNode *node in _nodes)
        [node.tree assertCounters];
}
*/ 

- (void) updateTreeRecursively
{
    _hasUnread = -1;
    _numReplies = _nodes.count;
    _numRecent = 0;
    
    for (VifNode *node in _nodes) {
        
        [node.tree updateTreeRecursively];
        
        _numReplies += node.tree->_numReplies;
        
        _numRecent += node.tree->_numRecent;
        if (node.isRecent)
            _numRecent++;
        
        _date = _date ? [node.date laterDate: _date] : node.date;
    }
}

@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface VifModel()
@property (readwrite, atomic) NSUInteger lastEvent;
@property (readwrite, nonatomic, strong) NSDate *prevDate;
@end

@implementation VifModel {
    
    HTTPRequest *_httpRequest;
    NSUInteger  _version;
}

+ (VifModel *) model
{
    static VifModel *gModel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        gModel = [[self alloc] init];
    });
    return gModel;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        _lastEvent = -1;
        _messageCache = [[VifMessageCache alloc] init];
    }
    return self;
}

- (void) save: (NSString *) path
{
    _version = 0;
    
    NSMutableArray *articles = [NSMutableArray array];
    [self collectArticles:articles];
    
    NSDictionary *dict = @{
        @"lastEvent" : @(_lastEvent),    
        @"articles" : articles,
    };
    
    if ([NSKeyedArchiver archiveRootObject:dict toFile:path]) {
        
        DDLogInfo(@"model saved, %d %d", _lastEvent, articles.count);
        
    } else {
        
        DDLogWarn(@"unable save model at %@", path);
    }
}

- (void) load: (NSString *) path
{
    _version = 0;
    [self reset];
    
    NSDate *ts = [NSDate date];
    
    id p = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    
    DDLogVerbose(@"VifModel.load: unarchive data in %.2fs", -[ts timeIntervalSinceNow]);
    
    if ([p isKindOfClass:[NSDictionary class]]) {
        
        ts = [NSDate date];
        
        NSDictionary *dict = p;
        
        self.lastEvent = [dict[@"lastEvent"] unsignedIntegerValue];
        NSArray *articles = dict[@"articles"];
        
        NSMutableDictionary *index = [NSMutableDictionary dictionary];
        for (VifArticle *article in articles)
            [self addArticle:article index:index];
            //[self addArticle:article];
        [self updateTreeRecursively];
        
        DDLogVerbose(@"VifModel.load: create tree in %.2fs", -[ts timeIntervalSinceNow]);
        DDLogInfo(@"model loaded, %d %d", self.lastEvent, articles.count);
        
    } else {
        
        DDLogWarn(@"unable load model at %@", path);
    }
}

- (BOOL) isDirty
{
    return _version > 0;
}

- (NSArray *) sortedNodes
{
    NSArray *nodes = [super sortedNodes];
    nodes = [nodes sortedArrayUsingComparator:^(VifNode *left, VifNode *right) {
        
        if (right.article.fixed > left.article.fixed)
            return NSOrderedDescending;
        if (right.article.fixed < left.article.fixed)
            return NSOrderedAscending;
        return NSOrderedSame;
        
    }];
    return nodes;
}

- (void) addArticle: (VifArticle *) article
              index: (NSMutableDictionary *) index
{
    VifNode *node;
    id parent = index[@(article.parent)];
    if (parent) {
        
        node = [[VifNode alloc] init:parent article:article];
        [((VifNode *)parent).tree addNode:node];
        
    } else {
        
        node = [self addArticle:article];
    }
    
    if (node)
        index[@(article.number)] = node;
}

- (VifNode *) addArticle: (VifArticle *) article
{
    VifNode *result = nil;
    
    if (article.parent)
        result = [super addArticle:article];
    
    if (!result) {
        
        result = [[VifNode alloc] init:nil article:article];
        [self addNode:result];
    }
    
    return result;
}

- (void) changeArticle: (NSUInteger) number
                parent: (NSUInteger) parentNumber
{   
    VifNode *node = [self findNode:number];
    if (node) {
        
        DDLogVerbose(@"change parent %@ -> %d", node.article, parentNumber);
        
        VifArticle *article = node.article;
        [node.parent.tree delArticle:number];
        
        article.parent = parentNumber;
        [self addArticle:article];
    }
}

- (void) fixArticle: (NSUInteger) number
               mode: (BOOL) mode
{   
    VifNode *node = [self findNode:number];
    if (node) {
        DDLogVerbose(@"fix %@", node.article);
        node.article.fixed = mode;
    }
}

- (BOOL) parseLastEvent: (NSData *) data __attribute__((deprecated))
{
    NSScanner *scanner = [NSScanner scannerWithString:[[NSString alloc] initWithData:data encoding:NSWindowsCP1251StringEncoding]];
    
    NSUInteger foundLastEvent = 0;
    NSUInteger minArticelID = INT_MAX;
    
    // find last event
    NSString *s;
    if ([scanner scanUpToString:@"new rTreeUpdater(" intoString:nil] &&
        [scanner scanString:@"new rTreeUpdater(" intoString:nil] &&
        [scanner scanUpToString:@"," intoString:&s] &&
        [scanner scanString:@"," intoString:nil] ) {
    
        foundLastEvent = s.integerValue;        
    }
        
    // find lower article id
    scanner.scanLocation = 0;
    while (!scanner.isAtEnd) {
        
        NSString *hexStr;
        
        if ([scanner scanUpToString:@"<ul id='a" intoString:nil] &&
            [scanner scanString:@"<ul id='a" intoString:nil] &&
            [scanner scanUpToString:@"'>" intoString:&hexStr] &&
            [scanner scanString:@"'>" intoString:nil] ) {
            
            NSUInteger number = parseIntegerValueFromHex(hexStr);
            if (number < minArticelID && number > 2390869) {
                
                minArticelID = number;
            }
            
        } else {
            
            break;
        }
    }
    
    if (minArticelID == INT_MAX)
        minArticelID = 0;

    DDLogInfo(@"foundLastEvent %d minArticelID %d", foundLastEvent, minArticelID);
    
    if (!minArticelID && !foundLastEvent)
        return NO;
    
    if (minArticelID)
        minArticelID -= 1390869; // yes, it's MAGIC CONSTANT, hey-ho !!!
    
    if (foundLastEvent)
        foundLastEvent -= 2000;  // suppose, we can load at least 2000 articles
    
    self.lastEvent = MAX(minArticelID, foundLastEvent);
    DDLogInfo(@"set lastEvent %d", self.lastEvent);
    
    return YES;
}

- (BOOL) parseXMLResponse: (NSData *) data
                resetTree: (BOOL) resetTree
                    error: (NSError **) perror

{    
    NSDictionary *dict = [XmlReader read:fixBrokenTitleInXML(data) error:perror];
    if (!dict) {

        DDLogWarn(@"unable parse response '%@'", *perror);
        return NO;
    }
        
    NSDictionary *root =  dict[@"root"];
    NSString *s = root[@"lastEvent"];
    if (!s) {
        if (perror)
            *perror = vifModelError(VifModelErrorWrongXMLResponse, nil);
        return NO;
    }
    
    self.prevDate = self.date;
    
    id p = root[@"event"];
    if (!p) {
        
        // no changes
        [self resetCountersRecursively];
        return YES;
    }
    
    DDLogVerbose(@"set lastEvent %d", s.integerValue);
    self.lastEvent = s.integerValue;
    
    if (resetTree) {
        
        [self reset];
        [_messageCache reset];
    }
    
    NSDate *ts = [NSDate date];
    
    NSArray *events = [p isKindOfClass:[NSArray class]] ? p : @[ p ];
    
    NSUInteger nadd = 0, ndel = 0, nfix = 0, nparent = 0;
    
    NSMutableDictionary *index = [NSMutableDictionary dictionary];

    for (NSDictionary *dict in events) {

        NSString *type = dict[@"type"];
        if ([type isEqualToString:@"add"]) {
            
            VifArticle *article = [[VifArticle alloc] initFromDictionary:dict];
            //[self addArticle:article];
            [self addArticle:article index:index];
            ++nadd;
            
        } else {
            
            const NSUInteger number = parseIntegerValueFromHex(dict[@"no"]);
            
            if ([type isEqualToString:@"del"]) {
                
                DDLogVerbose(@"del article %d", number);
                
                [self delArticle:number];
                [_messageCache removeMessage:number];
                ++ndel;
                
            } else if ([type isEqualToString:@"parent"]) {
                
                NSUInteger parent = parseIntegerValueFromHex(dict[@"parent"]);
                [self changeArticle:number parent:parent];
                ++nparent;
                
            } else if ([type isEqualToString:@"fix"]) {
                
                id p = dict[@"mode"];
                const BOOL mode = [p isEqualToString:@"1"];
                [self fixArticle:number mode:mode];                
                ++nfix;
            }
        }
    }    
    
    _version++;
        
    [self updateTreeRecursively];
    
    DDLogVerbose(@"VifModel.parseXMLResponse: update tree in %.2fs", -[ts timeIntervalSinceNow]);
    DDLogInfo(@"result add:%d\ndel: %d\nparent:%d\nfix: %d", nadd, ndel, nparent, nfix);
    
    return YES;
}

- (void) asyncUpdate: (VifModelBlock) block
{    
    [self asyncLoadXMLTree:block resetTree:NO];
}

- (void) asyncLoadXMLTree: (VifModelBlock) block
                resetTree: (BOOL) resetTree
{
    DDLogVerbose(@"asyncLoadXMLTree '%d'", self.lastEvent);
    
    NSString *s = [NSString stringWithFormat: @"http://www.vif2ne.ru/nvk/forum/0/co/tree?xml=%d", self.lastEvent];
    NSURL *url = [NSURL URLWithString:s];
    
    [_httpRequest close];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    _httpRequest = [HTTPRequest httpGet:url
                                referer:@"http://www.vif2ne.ru/nvk/forum/0/co/tree"
                          authorization:[[VifSettings settings] authorization]
                               response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res)
                    {
                        if (res.statusCode == 200)
                            return YES;
                        
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        
                        if (res.statusCode == 201 && !resetTree) {
                            
                            DDLogInfo(@"lastEvent is invalid, reset tree");
                            self.lastEvent = -1;
                            [self asyncLoadXMLTree:block resetTree:YES];
                            
                        } else {
                            
                            if (block) {
                                
                                NSString *s = [NSHTTPURLResponse localizedStringForStatusCode: res.statusCode];
                                block(vifModelError(VifModelErrorHTTPFailure, @"%d %@", res.statusCode, s));
                            }
                        }
                        
                        return NO;
                    }
                               progress:nil
                               complete:^(HTTPRequest *req, NSData *data, NSError *error)
                    {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        
                        if (error) {
                            
                            DDLogWarn(@"HTTP failure '%@'", error);
                            if (block)
                                block(error);
                            
                        } else {
                            
                            const NSUInteger v = _version;
                            
                            NSError *error;
                            if ([self parseXMLResponse:data
                                             resetTree:resetTree
                                                 error:&error]) {
                                
                                if (block)
                                    block(@(v != _version));
                                
                            } else {
                            
                                if (block)
                                    block(error);
                            }
                        }                        
                    }];
}

- (void) asyncLoadHTMLTree: (VifModelBlock) block __attribute__((deprecated))
{
    DDLogVerbose(@"asyncLoadHTMLTree");
    
    NSURL *url = [NSURL URLWithString:@"http://www.vif2ne.ru/nvk/forum/0/co/tree"];
    
    [_httpRequest close];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    _httpRequest = [HTTPRequest httpGet:url
                                referer:@"http://www.vif2ne.ru/nvk/forum/0/"
                          authorization:[[VifSettings settings] authorization]
                               response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res)
                    {
                        if (res.statusCode == 200)
                            return YES;
                                                
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        
                        if (block) {
                            
                            NSString *s = [NSHTTPURLResponse localizedStringForStatusCode: res.statusCode];
                            block(vifModelError(VifModelErrorHTTPFailure, @"%d %@", res.statusCode, s));
                        }
                        
                        return NO;
                    }
                               progress:nil
                               complete:^(HTTPRequest *req, NSData *data, NSError *error)
                    {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        
                        if (error) {
                            
                            DDLogWarn(@"HTTP failure '%@'", error);
                            if (block)
                                block(error);
                            
                        } else {
                            
                            if ([self parseLastEvent:data]) {
                                
                                [self asyncLoadXMLTree:block resetTree:YES];
                                
                            } else {
                                
                                if (block)
                                    block(vifModelError(VifModelErrorUnableParseLastEvent, nil));
                            }
                        }
                        
                    }];
}

- (void) cancelAll
{
    [_httpRequest close];
    _httpRequest = nil;
    [_messageCache cancelAll];
}

- (void) postMessage: (NSUInteger) articleNumber
             subject: (NSString *) subject
                body: (NSString *) body
{
    NSString *path;
    if (articleNumber)
        path = [NSString stringWithFormat: @"http://vif2ne.ru/nvk/forum/0/security/reply/%d", articleNumber];
    else
        path = @"http://vif2ne.ru/nvk/forum/0/security/new";
    
    NSDictionary *parameter = @{
    @"subject": subject,
    @"body": body
    
    // toplevel, hello, bye
    };
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    [HTTPRequest httpPost:[NSURL URLWithString: path]
                  referer:nil
            authorization:[[VifSettings settings] authorization]
               parameters:parameter
                 encoding:NSWindowsCP1251StringEncoding
                 response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res)
     {
         DDLogVerbose(@"status: %d", res.statusCode);
         DDLogVerbose(@"headers: %@", res.responseHeaders);
         
         [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
         
         if (res.statusCode != 200) {
             
             NSString *s = [NSHTTPURLResponse localizedStringForStatusCode: res.statusCode];
             s = [NSString stringWithFormat:@"%d %@", res.statusCode, s];
             
             [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"HTTP failure", nil)
                                         message:s
                                        delegate:nil
                               cancelButtonTitle:NSLocalizedString(@"Close", nil)
                               otherButtonTitles:nil] show];
             
         }
         
         return NO;
     }
                 progress:nil
                 complete:^(HTTPRequest *req, NSData *data, NSError *error)
     {
         if (error)
             DDLogVerbose(@"%@", error);
         if (data)
             DDLogVerbose(@"%@", [[NSString alloc] initWithData:data encoding:NSWindowsCP1251StringEncoding]);
         
     }];

}

@end
