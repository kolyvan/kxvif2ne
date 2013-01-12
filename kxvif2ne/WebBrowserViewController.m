//
//  WebBrowserViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 23.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "WebBrowserViewController.h"
#import "KxUtils.h"
#import "NSString+Kolyvan.h"
#import "QuartzCore/QuartzCore.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

//////

@interface WebBrowserViewController () {
    
    UIWebView               *_webView;
    UIToolbar               *_toolBar;
    UIBarButtonItem         *_backBarButton;
    UIBarButtonItem         *_forwardBarButton;
    UIActivityIndicatorView *_activityIndicator;
}
@end

@implementation WebBrowserViewController

- (id) init
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"";        
    }
    return self;
}

- (void) loadView
{
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    
    self.view = [[UIView alloc] initWithFrame:frame];
    
    //setup webview
    
    _webView = [[UIWebView alloc] initWithFrame:frame];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.scalesPageToFit = YES;
    _webView.delegate = self;
    
    [self.view addSubview:_webView];
    
    // setup toolbar
    
    _toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, frame.size.height-36, frame.size.width, 36)];
    
    _toolBar.barStyle = UIBarStyleBlackTranslucent;
    _toolBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    _backBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"webback"]
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(goBack)];
    
    _forwardBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"webforward"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(goForward)];
    
    UIBarButtonItem *fixedItem, *flexItem, *actionBarButton;    
    
    actionBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                    target:self
                                                                    action:@selector(goAction)];
    
    flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                             target:nil
                                                             action:nil];
    
    fixedItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                              target:nil
                                                              action:nil];
    fixedItem.width = 16;
    
    [_toolBar setItems:@[_backBarButton, fixedItem, _forwardBarButton, flexItem, actionBarButton ]];
    
    
    CGFloat X = frame.size.width * 0.5 - 16;
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(X, 0, 36, 36)];
    _activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    [_toolBar addSubview:_activityIndicator];
    
    [self.view addSubview:_toolBar];
     
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(navigationBack)];
    self.navigationItem.leftBarButtonItem = b;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_url)
        [self loadWebViewWithURL:_url];
    else
        [self loadHomePage];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) loadWebViewWithURL: (NSURL *) url
{
    DDLogVerbose(@"load url %@", url);
    [_webView loadRequest:[NSURLRequest requestWithURL: url]];
}

- (void) loadHomePage
{
    [self loadWebViewWithURL:[NSURL URLWithString: @"about:blank"]];
}

- (void) goBack
{
    [_webView goBack];
}

- (void) goForward
{
    [_webView goForward];
}

- (void) goAction
{
    UIActionSheet *actionSheet;
    actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                destructiveButtonTitle:nil
                                     otherButtonTitles:NSLocalizedString(@"Open in Safari", nil), NSLocalizedString(@"Copy link", nil), nil];
    
    [actionSheet showFromToolbar:_toolBar];
}

- (void) updateState: (NSString *) path
{    
    if (path.length) {
                
        self.title = [NSString stringWithFormat:NSLocalizedString(@"Loading %@", nil), path];
        [_activityIndicator startAnimating];
        
    } else {
        
        NSString *s = [_webView stringByEvaluatingJavaScriptFromString: @"document.title;"];
        self.title = s.length ? s : _webView.request.mainDocumentURL.absoluteString;
        [_activityIndicator stopAnimating];
    }
    
    _backBarButton.enabled = _webView.canGoBack;
    _forwardBarButton.enabled = _webView.canGoForward;
}

- (void) navigationBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIWebView delegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    if (![webView.request.mainDocumentURL isEqual:webView.request.URL])
        return;
    
    [self updateState: nil];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
    if (![webView.request.mainDocumentURL isEqual:webView.request.URL])
        return;
    
    [self updateState: nil];
    
    if (error.code == NSURLErrorCancelled && [error.domain isEqualToString:NSURLErrorDomain]) {
        
        DDLogWarn(@"didFailLoadWithError canceled %@", webView.request.URL);
        
    } else {
    
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"Close", nil)
                          otherButtonTitles:nil] show];
        
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;    
}

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{    
    //if (navigationType == UIWebViewNavigationTypeLinkClicked) {}
    //if (navigationType == UIWebViewNavigationTypeFormSubmitted) {}
    
    if ([request.mainDocumentURL isEqual:request.URL]) {
                
        [self updateState: request.mainDocumentURL.host];
    }
        
    return YES;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.firstOtherButtonIndex) {
        
        UIApplication *app = [UIApplication sharedApplication];
        if ([app canOpenURL:_webView.request.mainDocumentURL])
            [app openURL:_webView.request.mainDocumentURL];
        
    } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
        
        NSString *s = _webView.request.mainDocumentURL.absoluteString;
        if (s.length) {
            UIPasteboard *pb = [UIPasteboard generalPasteboard];
            [pb setString:s];
        }
    }
}

@end
