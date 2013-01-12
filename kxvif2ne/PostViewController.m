//
//  PostViewController.m
//  kxvif2ne
//
//  Created by Kolyvan on 11.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "PostViewController.h"
#import "ColorTheme.h"
#import "VifModel.h"
#import "VifMessageCache.h"
#import "VifSettings.h"
#import "HTTPRequest.h"
#import "NSString+Kolyvan.h"
#import "helpers.h"

@interface PostViewController ()
@end

@implementation PostViewController {
    
    UIBarButtonItem *_sendButton;
    UITextView      *_textView;
    BOOL            _needReloadTextView;
}

- (void) setArticle:(VifArticle *)article
{
    if (_article != article) {
        
        _article = article;
        _needReloadTextView = YES;
    }
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) loadView
{
    ColorTheme *theme = [ColorTheme theme];
    
    CGRect bounds = [[UIScreen mainScreen] applicationFrame];    
    const CGFloat W = bounds.size.width;
    const CGFloat H = bounds.size.height;
    
    self.view = [[UIView alloc] initWithFrame:bounds];
    
    _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    _textView.spellCheckingType = UITextSpellCheckingTypeYes;
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.textColor = theme.textColor;
    _textView.backgroundColor = theme.backgroundColor;
    _textView.returnKeyType = UIReturnKeyDefault;
    _textView.font = [UIFont systemFontOfSize:14];
    
    _textView.delegate = self;
    
    [self.view addSubview:_textView];    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //set notification for when keyboard shows/hides
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    
    _sendButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Post message", nil)
                                                   style:UIBarButtonItemStylePlain
                                                  target:self
                                                  action:@selector(didTouchSend)];
    
    _sendButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = _sendButton;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
        
    if (_needReloadTextView) {
        
        _needReloadTextView = NO;
        
        NSString *newText = @"";
        
        if (_article) {
        
            NSMutableString *ms = [NSMutableString string];
            [ms appendFormat:@"Re: %@\n\n", _article.title];
                        
            id p = [[[VifModel model] messageCache] lookupMessage:_article.number];
            if ([p isKindOfClass:[NSData class]]) {
                
                NSString *message = [[NSString alloc] initWithData:p encoding:NSUTF8StringEncoding];
                
                message = stripHTMLTags(message);
                
                for (NSString *s in message.lines) {
                    if (s.length) {
                        [ms appendString:@"> "];
                        [ms appendString:s.trimmed];
                        [ms appendString:@"\n"];
                    }
                    //[ms appendString:@"\n"];
                }
                
                [ms appendString:@"\n"];
            }
            
            newText = ms;
        }
        
        _textView.text = newText;        
    }
    
    _sendButton.enabled = _textView.text.length > 0;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_textView becomeFirstResponder];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_textView resignFirstResponder];
}

-(void) keyboardWillShow:(NSNotification *)note
{
	CGRect bounds;
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &bounds];
    
    bounds = [self.view.window convertRect:bounds fromWindow:nil];
    bounds = [self.view convertRect:bounds fromView:nil];
    
	CGFloat height = bounds.origin.y;
	CGRect frame = _textView.frame;
    
    if (frame.size.height != height) {
        
        frame.size.height = height;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationDuration:0.3f];
        _textView.frame = frame;
        [UIView commitAnimations];
    }
}

- (void) didTouchSend
{
    NSString * message = _textView.text;
    if (message.length) {
        
        // TODO: post message
        // take the first line as title
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    _sendButton.enabled = textView.text.length > 0;
}

@end
