//
//  VifSettings.h
//  kxvif2ne
//
//  Created by Kolyvan on 10.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

@interface VifSettings : NSObject
@property (readwrite, nonatomic, strong) NSString *loginName;
@property (readwrite, nonatomic, strong) NSString *colorTheme;
@property (readwrite, nonatomic) BOOL plainMode;

@property (readwrite, nonatomic) NSString *authorization;

+ (id) settings;

- (BOOL) reload;

- (void) login: (NSString *) name
      password: (NSString *) pass;

@end
