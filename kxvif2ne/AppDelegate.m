//
//  AppDelegate.m
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "AppDelegate.h"
#import "VifModel.h"
#import "KxUtils.h"
#import "TreeViewController.h"
#import "WebBrowserViewController.h"
#import "ColorTheme.h"
#import "VifSettings.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#import "HTTPRequest.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation AppDelegate {
    
    TreeViewController *_treeViewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setup];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    if (1) {
        
        _treeViewController = [[TreeViewController alloc] init];
        self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:_treeViewController];
        
    } else {
        
        [self test];
    }
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{   
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    VifModel *model = [VifModel model];
    if (model.isDirty)
       [model save:KxUtils.pathForPrivateFile(@"model.dat")];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{    
    VifSettings *settings = [VifSettings settings];
    if ([settings reload]) {
        
        ColorTheme *theme = [ColorTheme theme];
        
        if (![theme.name isEqualToString:settings.colorTheme]) {
            
            [ColorTheme setup: settings.colorTheme];
            
            _treeViewController = [[TreeViewController alloc] init];
            self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:_treeViewController];
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{    
    if (([url.host isEqualToString:@"vif2ne.ru"] ||
         [url.host isEqualToString:@"www.vif2ne.ru"]) &&
         [url.path hasPrefix:@"/nvk/forum/0/co/"] &&
         [url.pathExtension isEqualToString:@"htm"]) {
        
        NSString *s = url.lastPathComponent;
        s = [s substringToIndex: s.length - 4];

        if ([_treeViewController openArticle:s.integerValue])
            return YES;
    }
    
    [self openURLInWebBrowserController: url];
    return YES;
}

- (void) openURLInWebBrowserController: (NSURL *) url
{
    WebBrowserViewController *wbc = [[WebBrowserViewController alloc] init];
    wbc.url = url;
    UINavigationController *navController = (UINavigationController *)self.window.rootViewController;
    [navController pushViewController:wbc animated:YES];
}

- (void) setup
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DDLogVerbose(@"setup logger");
    
    if (1) {
        
        NSString *path = KxUtils.pathForPrivateFile(@"model.dat");
        if (KxUtils.fileExists(path))
            [[VifModel model] load:path];
        
    } else {
        
        [VifModel.model asyncUpdate:nil];
    }
    
    VifSettings *settings = [VifSettings settings];
    [settings reload];
    [ColorTheme setup: settings.colorTheme];    
}


- (void) test
{
    WebBrowserViewController *wbc = [[WebBrowserViewController alloc] init];
    wbc.url = [NSURL URLWithString:@"http://pda.lenta.ru"];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:wbc];
    
    // http://httpbin.org/post
    // http://posttestserver.com/post.php
    
    [HTTPRequest httpPost:[NSURL URLWithString: @"http://httpbin.org/post"]
                  referer:nil
            authorization:nil
               parameters:@{@"key1": @"test escape ?&!", @"key2" : @"http://pda.lenta.ru?x=1&z=3", @"key3" : @"проверка"}
                 encoding:NSUTF8StringEncoding
                 response:^BOOL(HTTPRequest *req, HTTPRequestResponse *res) {
                     
                     DDLogVerbose(@"status: %d", res.statusCode);
                     DDLogVerbose(@"headers: %@", res.responseHeaders);
                     
                     return YES;
                 }
                 progress:nil
                 complete:^(HTTPRequest *req, NSData *data, NSError *error) {
                     
                     if (error)
                         DDLogVerbose(@"%@", error);
                     if (data)
                         DDLogVerbose(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                     
                 }];
}


@end
