//
//  VifSettings.m
//  kxvif2ne
//
//  Created by Kolyvan on 10.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "VifSettings.h"
#import "DDLog.h"
#import "NSString+Kolyvan.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation VifSettings

+ (id) settings
{
    static VifSettings* gSettings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        gSettings = [[VifSettings alloc] init];
    });
    
    return gSettings;
}

- (id) init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (BOOL) reload
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
    
    NSString *loginName  = [userDefaults stringForKey:@"loginName"];
    NSString *colorTheme = [userDefaults stringForKey:@"colorTheme"];
    BOOL plainMode  = [userDefaults boolForKey:@"plainMode"];
    
    DDLogVerbose(@"user defaults: %@,%@,%d", loginName, colorTheme, plainMode);
    
    BOOL result = _plainMode != plainMode ||
                    ![_loginName isEqualToString:loginName] ||
                    ![_colorTheme isEqualToString:colorTheme];
    
    _loginName = loginName;
    _colorTheme = colorTheme;
    _plainMode = plainMode;
    
    return result;
}

- (void) login: (NSString *) name
      password: (NSString *) pass
{
    if (![_loginName isEqualToString: name]) {
    
        _loginName = name;        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:name ? name : @"" forKey:@"loginName"];
        [userDefaults synchronize];
    }
    
    if (name.length && pass.length) {
        
        NSString *s = [NSString stringWithFormat:@"%@:%@", name, pass];
        _authorization = [NSString stringWithFormat:@"Basic %@", s.base64encode];
        
        DDLogVerbose(@"Authorization: %@", _authorization);
        
    } else {
    
        _authorization = nil;
    }
}

@end
