//
//  VifMessageCache.m
//  kxvif2ne
//
//  Created by Kolyvan on 09.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "VifMessageCache.h"
#import "VifModel.h"
#import "VifSettings.h"
#import "HTTPRequest.h"
#import "NSDate+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "KxUtils.h"
#import "DDLog.h"
#import "helpers.h"

static int ddLogLevel = LOG_LEVEL_INFO;

#define FETCH_FORMAT @"http://vif2ne.ru/nvk/forum/0/co/%d.htm"
#define FETCH_REFERER @"http://vif2ne.ru/nvk/forum/0/co/tree"

#define STORE_FOLDER @"articles"

#define MAX_SIZE_CACHED_MESSAGES (1<<21)
#define MAX_SIZE_STORED_FILES (1<<23)
#define MAX_NUM_STORED_FILES (1<<11)
#define MAX_TIME_STORED_FILES (3600*24*7)

#define BEGIN_TAG @"<hr size=1></h3></center>"
#define END_TAG @"<br><hr size=1>"
#define BEGIN_BODY_TAG @"<body"
#define END_BODY_TAG @"</body>"

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface VifMessageCache()
@property (readwrite, nonatomic, strong) NSMutableArray *files;
@end

@implementation VifMessageCache {
    
    NSMutableArray      *_httpRequests;
    NSMutableDictionary *_cache;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        _httpRequests = [NSMutableArray array];
        _cache = [NSMutableDictionary dictionary];
        
        //_files = [NSMutableArray array];
        //[self refreshFiles];
        
        NSDate *ts = [NSDate date];        
        _files = [VifMessageCache refreshFiles];
        DDLogVerbose(@"VifMessageCache: refresh files in %.2fs", -[ts timeIntervalSinceNow]);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:[UIApplication sharedApplication]];
        
    }
    return self;
}

- (void) dealloc
{    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) applicationDidEnterBackground: (NSNotification *)notification
{
    [self cancelAll];
    [_cache removeAllObjects];
}

- (void) applicationDidReceiveMemoryWarning: (NSNotification *)notification
{
    [_cache removeAllObjects];
}

- (BOOL) containsMessage: (NSUInteger) articleNumber
{
    NSNumber *n = @(articleNumber);
    return [_cache objectForKey:n] || [_files containsObject:n];
}

- (id) lookupMessage: (NSUInteger) articleNumber
{
    return _cache[@(articleNumber)];
}

+ (NSString *) pathForFolder
{
    return KxUtils.pathForCacheFile(STORE_FOLDER);
}

+ (NSString *) pathForArticle: (NSUInteger) articleNumber
{
    NSString *filename = [NSString stringWithFormat: @"%d", articleNumber];
    NSString *path = [STORE_FOLDER stringByAppendingPathComponent:filename];
    return KxUtils.pathForCacheFile(path);
}

- (void) storeFile: (NSUInteger) articleNumber
           message: (NSString *) message
{
    DDLogVerbose(@"store file %d", articleNumber);
        
    NSError *error;
    NSString *path = [VifMessageCache pathForArticle: articleNumber];
    if ([message writeToFile:path
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:&error]) {
        
        [_files addObject:@(articleNumber)];
        
    } else {
        
        DDLogWarn(@"Unable save file at '%@' %@", path, error);
    }
}

- (void) completeFetch:(NSUInteger) articleNumber
               message:(NSData *) message
                 error:(NSError *) error
                 block:(VifMessageCacheBlock) block
{
    drainCacheIfExcess(_cache, MAX_SIZE_CACHED_MESSAGES);
    
    _cache[@(articleNumber)] = error ? error : message;
    block(articleNumber, error ? error : message);
}

- (void) fetchFile:(NSUInteger) articleNumber
              path:(NSString *) path
             block:(void(^)(NSUInteger number, id result)) block
{
    DDLogVerbose(@"fetch file %d", articleNumber);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSError *error;
        NSData *msg = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (error) {
            
            NSFileManager *fm = [[NSFileManager alloc] init];
            [fm removeItemAtPath:path error:nil];            
            DDLogWarn(@"Unable load file at '%@' %@", path, error);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (error) {
                [_files removeObject:@(articleNumber)];
            }
            
            [self completeFetch:articleNumber message:msg error:error block:block];
        });
    });
}

- (void) fetchURL:(NSUInteger) articleNumber
            block:(VifMessageCacheBlock) block
{
    DDLogVerbose(@"fetch url %d", articleNumber);
    
    [self garbageRequests];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:FETCH_FORMAT, articleNumber]];
    
    HTTPRequest *r;
    r = [HTTPRequest httpGet:url
                     referer:FETCH_REFERER
               authorization:[[VifSettings settings] authorization]
                    response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res)
         {
             if (res.statusCode == 200)
                 return YES;
             
             [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
             
             NSString *s = [NSHTTPURLResponse localizedStringForStatusCode: res.statusCode];
             s = [NSString stringWithFormat:@"%d %@", res.statusCode, s];
             NSError *error = vifModelError(VifModelErrorHTTPFailure, s);
             
             [self completeFetch:articleNumber message:nil error:error block:block];
             return NO;
         }
                    progress:nil
                    complete:^(HTTPRequest *req, NSData *data, NSError *error)
         {
             [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
             
             if (error) {
                 
                 [self completeFetch:articleNumber message:nil error:error block:block];
                 
             } else {
                 
                 NSString *message = [VifMessageCache parseArticleData: data];
                 if (message.length) {
                     
                     message = stripHTMLComment(message);
                     message = fixBrokenURLInHTML(message);
                     
                     [self storeFile:articleNumber message:message];
                     NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
                     [self completeFetch:articleNumber message:data error:nil block:block];
                     
                 } else {
                     
                     NSError *error = vifModelError(VifModelErrorUnableParseArticle, nil);
                     [self completeFetch:articleNumber message:nil error:error block:block];
                 }
             }
             
         }];
    
    if (r) {
        
        [_httpRequests addObject:r];
        
    } else {
        
        NSError *error = vifModelError(VifModelErrorNetworkFailure, nil);
        [self completeFetch:articleNumber message:nil error:error block:block];
    }    
}

- (void) fetchMessage: (NSUInteger) articleNumber
                block: (VifMessageCacheBlock) block
{
    NSAssert(block, @"NULL block");
    
    _cache[@(articleNumber)] = [NSNull null];
    
    NSString *path = [VifMessageCache pathForArticle: articleNumber];
    
    if (KxUtils.fileExists(path)) {
        
        [self fetchFile:articleNumber path:path block:block];
        
    } else {

        [self fetchURL:articleNumber block:block];        
    }
}

- (void) removeMessage:(NSUInteger) articleNumber
{
    NSNumber *n = @(articleNumber);
    [_cache removeObjectForKey:n];
    [_files removeObject:n];
    
    NSString *path = [VifMessageCache pathForArticle: articleNumber];
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    if ([fm fileExistsAtPath:path]) {
        
        if ([fm removeItemAtPath:path error:&error])
            DDLogVerbose(@"Remove file at '%@'", path);
        else
            DDLogWarn(@"Unable remove file at '%@' %@", path, error);
    }
}

+ (NSMutableArray *) refreshFiles
{
    NSMutableArray *files = [NSMutableArray array];
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];    
    NSString *folder = [VifMessageCache pathForFolder];
    
    if (![fm fileExistsAtPath:folder]) {
        
        if (![fm createDirectoryAtPath:folder
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error]) {
            
            DDLogWarn(@"Unable create folder at '%@' %@", folder, error);            
        }
        return files;
    }
   
    NSArray *content = [fm contentsOfDirectoryAtPath:folder error:&error];
    
    if (error) {
        
        DDLogWarn(@"Unable get content at '%@' %@", folder, error);
        return nil;
    }
    
    NSDate *lastDate = [[NSDate date] addSeconds:-MAX_TIME_STORED_FILES];
    
    unsigned long long totalSize = 0;
    NSUInteger numRemoved = 0;
    
    for (NSString *filename in content) {
        
        if (filename.length && [filename characterAtIndex:0] != '.') {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
            
                id fileType = [attr objectForKey:NSFileType];
                
                if ([fileType isEqual: NSFileTypeRegular]) {
                    
                    NSUInteger number = [filename integerValue];
                    NSDate *date = [attr objectForKey:NSFileModificationDate];
                    unsigned long long size = [[attr objectForKey:NSFileSize] unsignedLongLongValue];
                    
                    if (!number ||
                        files.count > MAX_NUM_STORED_FILES ||
                        [date isLess: lastDate] ||
                        (totalSize + size) > MAX_SIZE_STORED_FILES) {
                    
                        if ([fm removeItemAtPath:path error:&error]) {
                         
                            ++numRemoved;
                            
                        } else {
                            
                            DDLogWarn(@"Unable remove file at '%@' %@", path, error);
                        }
                        
                    } else {
                        
                        totalSize += size;
                        [files addObject:@(number)];
                    }
                }
            }
        }
    }
        
    DDLogInfo(@"refresh files: %d of size %lldKb, removed: %d",
              files.count, totalSize / 1042, numRemoved);
    
    return files;
}

- (void) refreshFiles
{
    __weak VifMessageCache *weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSMutableArray *result = [VifMessageCache refreshFiles];
        
        dispatch_async(dispatch_get_main_queue(), ^{

            __strong VifMessageCache *strongSelf = weakSelf;
            if (strongSelf)
                strongSelf.files = result;
        });
    });
}

- (void) cancelAll
{
    for (HTTPRequest *r in _httpRequests)
        [r close];
    [_httpRequests removeAllObjects];
}

- (void) garbageRequests
{
    NSUInteger i = 0;
    while (i < _httpRequests.count) {
        
        HTTPRequest *r = _httpRequests[i];
        if (r.isClosed) {
            [_httpRequests removeObjectAtIndex:i];
        } else {
            ++i;
        }
    }
}

+ (NSString *) parseArticleData: (NSData *) data
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSWindowsCP1251StringEncoding];
    
    NSScanner *scanner = [NSScanner scannerWithString:s];
    
    NSString *x;
    
    if ([scanner scanUpToString:BEGIN_TAG intoString:nil] &&
        [scanner scanString:BEGIN_TAG intoString:nil] &&
        [scanner scanUpToString:END_TAG intoString:&x] &&
        [scanner scanString:END_TAG intoString:nil] ) {
        
        return x;
    }
    
    x = nil;
    scanner.scanLocation = 0;
    
    if ([scanner scanUpToString:BEGIN_BODY_TAG intoString:nil] &&
        [scanner scanString:BEGIN_BODY_TAG intoString:nil] &&
        [scanner scanUpToString:@">" intoString:nil] &&
        [scanner scanString:@">" intoString:nil] &&
        [scanner scanUpToString:END_BODY_TAG intoString:&x] &&
        [scanner scanString:END_BODY_TAG intoString:nil] ) {
        
        return x;
    }
    
    //return stripHTMLTags(s);
    return nil;
}

- (void) reset
{
    [_cache removeAllObjects];
    [_files removeAllObjects];
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [VifMessageCache pathForFolder];
    
    if ([fm fileExistsAtPath:folder] &&
        [fm removeItemAtPath:folder
                       error:&error] &&
        [fm createDirectoryAtPath:folder
      withIntermediateDirectories:YES
                       attributes:nil
                            error:&error]) {
            
            DDLogVerbose(@"Clean folder at '%@'", folder);
            
        } else {
            
            DDLogWarn(@"Unable clean folder at '%@' %@", folder, error);
        }
}

@end