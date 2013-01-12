//
//  ImageLoader.m
//  kxvif2ne
//
//  Created by Kolyvan on 08.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "ImageLoader.h"
#import "helpers.h"

#define MAX_SIZE_CACHED_IMAGES (1<<21)

@implementation ImageLoader {
    
    NSMutableDictionary *_cache;
}

+ (id) imageLoader
{
    static ImageLoader *gImageLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        gImageLoader = [[ImageLoader alloc] init];
    });    
    return gImageLoader;
}

- (id)init
{
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        
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
    [_cache removeAllObjects];
}

- (void) applicationDidReceiveMemoryWarning: (NSNotification *)notification
{
    [_cache removeAllObjects];
}

- (void) asyncLoadImages: (NSArray *) sources
               completed: (BOOL(^)(UIImage *image, NSString *source)) completed
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (NSString *source in sources) {
            UIImage *image = [self loadImage:source];
            if (image) {
                __block BOOL good = YES;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    good = completed(image, source);
                });
                if (!good)
                    break;
            }
        }
    });
}

- (UIImage *) loadImage: (NSString *) source
{
    NSData *data = _cache[source];
    
    if (!data) {
        
        NSURL *url = [NSURL URLWithString:source];
        if (!url)
            return nil;
        
        data = [NSData dataWithContentsOfURL: url];
        if (!data)
            return nil;
        
        drainCacheIfExcess(_cache, MAX_SIZE_CACHED_IMAGES);
        
        _cache[source] = data;
    }
    
    return [UIImage imageWithData:data];    
}

@end
