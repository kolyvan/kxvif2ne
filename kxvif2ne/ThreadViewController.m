//
//  ThreadViewController.m
//  kxvif2ne
//
//  Created by Kolyvan on 07.01.13.
//  Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "ThreadViewController.h"
#import "ArticleCell.h"
#import "VifModel.h"
#import "VifSettings.h"
#import "VifMessageCache.h"
#import "ImageLoader.h"
#import "ColorTheme.h"
#import "helpers.h"
#import "NSDate+Kolyvan.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface ThreadViewController ()
@end

@implementation ThreadViewController {
    
    VifNode                 *_rootNode;
    NSMutableArray          *_thread;
    NSArray                 *_replies;
    NSIndexPath             *_selIndexPath;
    NSString                *_selText;
    KxHTMLRender            *_selHtmlRender;
    UISwipeGestureRecognizer*_swipeGestureRecognizer;
    UITapGestureRecognizer  *_tapGestureRecognizer;
    CGFloat                 _indentationWidth;
    BOOL                    _handleGestures;
    BOOL                    _needReload;
}

@dynamic rootNode;

- (VifNode *) rootNode
{
    return _rootNode;
}

- (void) setRootNode: (VifNode *) node
{
    if (node != _rootNode) {
        
        _rootNode = node;
        _needReload = YES;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        
        _thread = [NSMutableArray array];
        _indentationWidth = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? 5 : 10;
                
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            ColorTheme *theme = [ColorTheme theme];
            
            KxHTMLRenderStyleSheet *css = [KxHTMLRenderStyleSheet defaultStyleSheet];
            
            KxHTMLRenderStyle *style = [[KxHTMLRenderStyle alloc] init];
            style.color = theme.altTextColor;
            style.hyperlink = @(YES);
            [css addStyle:style withSelector:@"a"];
            
        });
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    _swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.tableView addGestureRecognizer:_swipeGestureRecognizer];
    
    _tapGestureRecognizer = [[UITapGestureRecognizer  alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.tableView addGestureRecognizer:_tapGestureRecognizer];
        
    UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(navigationBack)];
    self.navigationItem.leftBarButtonItem = b;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _handleGestures = YES;
    
    if (_needReload) {
        
        _needReload = NO;        
        _plainMode = [[VifSettings settings] plainMode];
        [self resetData];
        [self.tableView reloadData];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    if ((!_selIndexPath || ![_selIndexPath isEqual:indexPath]) && [_thread[0] isUnread])
        [self toggleNodeForIndexPath:indexPath];
}

#pragma mark - public

- (BOOL) openArticle: (NSUInteger) number
{
    VifNode *node = nil;
    
    if (self.rootNode.article.number == number ||
        nil != (node = [self.rootNode.tree findNode:number recursive:YES])) {
        
        if (node) {
            
            [_thread removeAllObjects];
            
            do {
                
                [_thread insertObject:node atIndex:0];
                node = node.parent;
                
            } while (node);
            
        } else if (_thread.count > 1) {
            
            [_thread removeObjectsInRange:NSMakeRange(1, _thread.count - 1)];
        }
        
        node = _thread.lastObject;
        _replies = _plainMode ? node.tree.sortedNodes : node.tree.deepSortedNodes;
        _selIndexPath = nil;
        
        [self.tableView reloadData];
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_thread.count - 1 inSection:0];
        
        //DDLogVerbose(@"toggle %@", indexPath);
        
        [self toggleNodeForIndexPath:indexPath];
        [self.tableView scrollToRowAtIndexPath:indexPath
                              atScrollPosition:UITableViewScrollPositionTop
                                      animated:YES];
        
        return YES;
    }
    
    return NO;
}

- (void) didTouchPostMessage
{
    VifArticle *article = nil;
    if (_selIndexPath)
        article = [self nodeForIndexPath:_selIndexPath].article;
    [self postMessage:article ? article : _rootNode.article];
}

#pragma mark - private

- (void) resetData
{
    [_thread removeAllObjects];
    [_thread addObject:_rootNode];
    
    _replies = _plainMode ? _rootNode.tree.sortedNodes : _rootNode.tree.deepSortedNodes;
    
    _selIndexPath = nil;
    _selText = nil;
    _selHtmlRender = nil;
}

- (void) navigationBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) handleSwipe:(UISwipeGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (!_handleGestures)
            return;
        
        CGPoint pt = [sender locationInView: self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: pt];
        
        if (!indexPath || !indexPath.section)
            return;
                
        _handleGestures = NO;        
        [self moveNodeForIndexPath: indexPath moveAll:YES];
        _handleGestures = YES;
    }
}

- (void) handleTap:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
 
        if (!_handleGestures)
            return;
        
        CGPoint pt = [sender locationInView: self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: pt];
        if (!indexPath)
            return;
        
        if (_selIndexPath && [_selIndexPath isEqual:indexPath]) {
            
            VifNodeCell *cell =  (VifNodeCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            
            CGPoint loc = [self.tableView convertPoint:pt toView:cell.contentView];
            if ([cell handleTouch:loc])
                return;
        }
        
        _handleGestures = NO;
        
        if (pt.x < self.view.bounds.size.width * 0.7)
            [self toggleNodeForIndexPath:indexPath];
        else
            [self moveNodeForIndexPath: indexPath moveAll:NO];
        
        _handleGestures = YES;
    }
}

- (void) replaceRepliesWithAnimation: (NSArray *) newNodes
{
    // remove nodes in section 1
    {
        NSMutableArray *toRemove = [NSMutableArray array];
        for (NSUInteger n = 0; n < _replies.count; ++n)
            [toRemove addObject:[NSIndexPath indexPathForRow:n inSection:1]];
        _replies = nil;
        [self.tableView deleteRowsAtIndexPaths:toRemove
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    // add nodes in section 1
    _replies = newNodes;
    
    if (_replies.count) {
        
        NSMutableArray *toAdd = [NSMutableArray array];
        for (NSUInteger n = 0; n < _replies.count; ++n)
            [toAdd addObject:[NSIndexPath indexPathForRow:n inSection:1]];
        
        [self.tableView insertRowsAtIndexPaths:toAdd
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }    
}

- (void) moveNodeForIndexPath: (NSIndexPath *) indexPath
                      moveAll: (BOOL) moveAll
{
    if (_selIndexPath) {
        
        NSIndexPath *prev = _selIndexPath;
        _selIndexPath = nil;
        [self.tableView reloadRowsAtIndexPaths:@[prev]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    if (indexPath.section) {
        
        if (moveAll)
            [self liftAllForIndexPath:indexPath];
        else
            [self liftNodeForIndexPath:indexPath];
        
    } else {
        
        [self dropNodeForIndexPath:indexPath];
    }
}

- (void) liftNodeForIndexPath: (NSIndexPath *) indexPath
{
    VifNode *node = _replies[indexPath.row];
    
    if (!node.tree.nodes.count)
        return;
    
    // move node from section 1 to section 0
    {
        [_thread addObject:node];
        
        NSMutableArray *ma = [_replies mutableCopy];
        [ma removeObjectAtIndex:indexPath.row];
        _replies = [ma copy];
        
        NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:_thread.count - 1 inSection:0];
        
        [self.tableView moveRowAtIndexPath:indexPath
                               toIndexPath:toIndexPath];
        
        if (!_plainMode) {
            // [self.tableView reloadRowsAtIndexPaths:@[toIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:toIndexPath];
            cell.indentationLevel = 0;
            [cell setNeedsDisplay];
        }
    }

    [self replaceRepliesWithAnimation: _plainMode ? node.tree.sortedNodes : node.tree.deepSortedNodes];
    
    indexPath = [NSIndexPath indexPathForRow:_thread.count - 1 inSection:0];
    
    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionTop
                                  animated:YES];
}

- (void) dropNodeForIndexPath: (NSIndexPath *) indexPath
{
    NSUInteger nRow = indexPath.row;
    if (nRow) {
        
        VifNode *node = _thread[indexPath.row];
        
        VifTree *tree = ((VifNode *)_thread[indexPath.row - 1]).tree;
        NSMutableArray *nodes = [_plainMode ? tree.sortedNodes : tree.deepSortedNodes mutableCopy];
        
         if (_plainMode) {
        
             // remove nodes in section 0
             
             ++nRow;
             if (nRow < _thread.count) {
                 
                 NSMutableArray *toRemove = [NSMutableArray array];
                 for (NSUInteger n = nRow; n < _thread.count; ++n)
                     [toRemove addObject:[NSIndexPath indexPathForRow:n inSection:0]];
                 
                 [_thread removeObjectsInRange:NSMakeRange(nRow, _thread.count - nRow)];
                 
                 [self.tableView deleteRowsAtIndexPaths:toRemove
                                       withRowAnimation:UITableViewRowAnimationAutomatic];
             }
                          
             // replace in section 0
             NSUInteger index = [nodes indexOfObject:node];
             [nodes removeObjectAtIndex:index];
             [self replaceRepliesWithAnimation: nodes];
             
             // move node from section 0 to section 1
             
             [_thread removeObject: node];
             
             NSMutableArray *ma = [_replies mutableCopy];
             [ma insertObject:node atIndex:index];
             _replies = [ma copy];
             
             [self.tableView moveRowAtIndexPath:indexPath
                                    toIndexPath:[NSIndexPath indexPathForRow:index inSection:1]];
             
             [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:1]
                                   atScrollPosition:UITableViewScrollPositionBottom
                                           animated:YES];
         } else {
         
             // remove nodes in section 0
                 
             if (nRow < _thread.count) {
                 
                 NSMutableArray *toRemove = [NSMutableArray array];
                 for (NSUInteger n = nRow; n < _thread.count; ++n)
                     [toRemove addObject:[NSIndexPath indexPathForRow:n inSection:0]];
                 
                 [_thread removeObjectsInRange:NSMakeRange(nRow, _thread.count - nRow)];
                 
                 [self.tableView deleteRowsAtIndexPaths:toRemove
                                       withRowAnimation:UITableViewRowAnimationAutomatic];
             }             
             
             [self replaceRepliesWithAnimation: nodes];
         }
    }
}

- (void) liftAllForIndexPath: (NSIndexPath *) indexPath
{
    NSAssert(indexPath.section == 1, @"invalid section");
        
    NSMutableArray *ma = [NSMutableArray array];
    
    VifNode *node = _replies[indexPath.row];
    
    // go to downward as possible
    
    do {
        
        [ma addObject:node];
        
        VifNode *candidate = nil;
        
        for (VifNode *r in node.tree.nodes) {
            
            if (r.isRecent) {
                candidate = nil;
                break;
            }
            
            if (!r.tree.nodes.count)
                continue;
            
            if (r.tree.numRecent > candidate.tree.numRecent)
                candidate = r;
            else if (r.tree.numRecent < candidate.tree.numRecent)
                continue;
            
            if (r.tree.hasUnread > candidate.tree.hasUnread)
                candidate = r;
            else if (r.tree.hasUnread < candidate.tree.hasUnread)
                continue;
            
            if (r.tree.numReplies > candidate.tree.numReplies)
                candidate = r;
            else if (r.tree.numReplies < candidate.tree.numReplies)
                continue;
            
            candidate = r;
        }
        
        node = candidate;
        
    } while (node);
    
    NSMutableArray *toAdd = [NSMutableArray array];
    for (NSUInteger i = 0; i < ma.count; ++i)
        [toAdd addObject:[NSIndexPath indexPathForRow:i + _thread.count inSection:0]];
    
    [_thread addObjectsFromArray:ma];
    
    [self.tableView insertRowsAtIndexPaths:toAdd
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    
    node = _thread.lastObject;
    [self replaceRepliesWithAnimation: _plainMode ? node.tree.sortedNodes : node.tree.deepSortedNodes];
    
    //indexPath = [NSIndexPath indexPathForRow:_thread.count - 1 inSection:0];
    //[self.tableView scrollToRowAtIndexPath:indexPath
    //                      atScrollPosition:UITableViewScrollPositionMiddle
    //                              animated:YES];
}

- (VifNode *) nodeForIndexPath: (NSIndexPath *) indexPath
{
    return (indexPath.section == 0) ? _thread[indexPath.row] : _replies[indexPath.row];
}

- (NSIndexPath *) indexPathForArticleNumber: (NSUInteger) articleNumber
{
    NSUInteger row;
    
    row = 0;
    for (VifNode *node in _thread) {
        if (node.article.number == articleNumber)
            return [NSIndexPath indexPathForRow:row inSection:0];
        ++row;
    }
    
    row = 0;
    for (VifNode *node in _replies) {
        if (node.article.number == articleNumber)
            return [NSIndexPath indexPathForRow:row inSection:1];
        ++row;
    }
    
    return nil;
}

- (void) reloadArticleCell:(NSUInteger)number
{    
    NSIndexPath *indexPath = [self indexPathForArticleNumber: number];
    if (indexPath && _selIndexPath && [_selIndexPath isEqual:indexPath]) {
        
        [self.tableView reloadRowsAtIndexPaths:@[indexPath ]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void) toggleNodeForIndexPath: (NSIndexPath *) indexPath
{    
    if ([_selIndexPath isEqual: indexPath]) {
        
        _selIndexPath = nil;
        
    } else {
        
        VifNode *node = [self nodeForIndexPath:indexPath];
        
        NSIndexPath *prevIndexPath = _selIndexPath;
        _selIndexPath = nil;
        
        if (prevIndexPath) {
            [self.tableView reloadRowsAtIndexPaths:@[ prevIndexPath ]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        _selIndexPath = indexPath;
                        
        if (node.isUnread)
            [node clearUnread];
            
        if (node.article.size > 0) {
            
            VifMessageCache *messageCache = [VifModel model].messageCache;
            id p = [messageCache lookupMessage:node.article.number];
            
            if (!p) {
                
                __weak id weakSelf = self;
                [messageCache fetchMessage:node.article.number
                                     block:^(NSUInteger number, id result)
                 {
                     __strong ThreadViewController *strongSelf = weakSelf;
                     if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
                         [strongSelf reloadArticleCell:number];
                 }];
            }
        }
    }

    [self.tableView reloadRowsAtIndexPaths:@[indexPath ]
                          withRowAnimation:UITableViewRowAnimationAutomatic];

    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionTop
                                  animated:YES];
}

- (NSUInteger) indentationLevelForNode: (VifNode *) node
{
    VifNode *last = _thread.lastObject;
    NSUInteger level = 0;
    node = node.parent;
    while (node && node != last) {
        node = node.parent;
        ++level;
    }
    return level;
}

- (void)doRefresh:(CKRefreshControl *)sender
{
    [VifModel.model asyncUpdateNode:_rootNode
                              block: ^(id result) {
        
        [self.refreshControl endRefreshing];
        
        if ([result isKindOfClass:[NSError class]]) {
            
            NSError *error = result;
            
            NSString *title = error.localizedDescription;
            NSString *message = error.userInfo[NSLocalizedFailureReasonErrorKey];
            
            [[[UIAlertView alloc] initWithTitle:title
                                        message:message ? message : @""
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
            
        } else {
            
            if ([result boolValue]) {
                
                [self resetData];
                [self.tableView reloadData];
            }
        }
    }];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VifNode *node = [self nodeForIndexPath:indexPath];
    
    if ([_selIndexPath isEqual:indexPath]) {
        
        _selHtmlRender = nil;
        _selText = nil;
        
        if (node.article.size > 0) {
        
            VifMessageCache *messageCache = [VifModel model].messageCache;
                        
            id p = [messageCache lookupMessage:node.article.number];
                
            if ([p isKindOfClass:[NSData class]]) {
                
                _selHtmlRender  = [KxHTMLRender renderFromHTML:p
                                                      encoding:NSUTF8StringEncoding
                                                      delegate:self];
                if (_selHtmlRender) {
                    
                    ColorTheme *theme = [ColorTheme theme];
                    _selHtmlRender.baseStyle.color = theme.textColor;
                    
                } else {
                    
                    _selText = [[NSString alloc] initWithData:p encoding:NSUTF8StringEncoding];
                    DDLogVerbose(@"invalid HTML:\n%@", _selText);
                    _selText = stripHTMLTags(_selText);
                }
                
            } else if ([p isKindOfClass:[NSError class]]) {
                
                _selText = [NSString stringWithFormat:@"(ERR: %@)", ((NSError *)p).localizedDescription];
                
            } else if ([p isKindOfClass:[NSString class]]) {
                
                _selText = p;
                
            } else if (p == [NSNull null]) {
                
                _selText = NSLocalizedString(@"(loading..)", nil);
                
            } else if (!p) {
                
                _selText = @"(ERR: NULL)";
                
            } else {
                
                _selText = [p description];
            }
            
            
        } else {
            
            _selText = @"(-)";
        }
    
        return MIN(2009, [VifNodeCell heightForNode:node
                                               text:_selText
                                         htmlRender:_selHtmlRender
                                          withWidth:self.cellWidth]);
    }    
    
    const NSUInteger indentationLevel = (_plainMode || !indexPath.section) ? 0 : [self indentationLevelForNode: node];
    
    return MIN(2009,[VifNodeCell heightForNode:node
                                          text:nil
                                    htmlRender:nil
                                     withWidth:self.cellWidth - indentationLevel * _indentationWidth]);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return _thread.count;
    if (section == 1)
        return _replies.count;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VifNode *node = [self nodeForIndexPath:indexPath];
    
    VifNodeCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"VifNodeCell"];
    if (cell == nil) {
        
        cell = [[VifNodeCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:@"VifNodeCell"];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.indentationWidth = _indentationWidth;
    }
    cell.node = node;
    
    if ([_selIndexPath isEqual: indexPath]) {
        
        cell.text = _selText;
        cell.htmlRender = _selHtmlRender;
        cell.indentationLevel = 0;
        
    } else {
        
        cell.text = nil;
        cell.htmlRender = nil;
        cell.indentationLevel = (_plainMode || !indexPath.section) ? 0 : [self indentationLevelForNode: node];
    }
    
    return cell;
}

#pragma mark - KxHTML delegate

- (BOOL) didImageLoad
{
    if (_selIndexPath) {
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_selIndexPath];
        [cell setNeedsDisplay];
        return YES;
    }
    
    return NO;
}

- (void) loadImages: (NSArray *) sources
          completed: (void(^)(UIImage *image, NSString *source)) completed
{
    __weak id w = self;
    
    ImageLoader *loader = [ImageLoader imageLoader];
    [loader asyncLoadImages:sources
                  completed:^(UIImage *image, NSString *source) {
        
        __strong id p = w;
        if (p && [p didImageLoad]) {
            completed(image, source);
            return YES;
        }
        return NO;
    }];
   
}

@end
