//
//  TreeViewController.m
//  kxvif2ne
//
//  Created by Kolyvan on 31.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "TreeViewController.h"
#import "ArticleCell.h"
#import "VifModel.h"
#import "ThreadViewController.h"
#import "CKRefreshControl.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

typedef struct
{
    NSInteger treeNumRecent;
    BOOL      treeHasUnread;
    BOOL      nodeIsUnread;
    
} NodeInfo;

@interface TreeViewController ()
@property (nonatomic,retain) UIRefreshControl *refreshControl;
@end

@implementation TreeViewController{
    
    NSArray                 *_nodes;
    ThreadViewController    *_threadViewController;
    NodeInfo                _storeNodeInfo;
}

- (id)init
{
    self = [super init];
    if (self) {
        _storeNodeInfo.treeNumRecent = -1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CKRefreshControl *refreshControl = [CKRefreshControl new];
    [refreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = (id)refreshControl;
    [self.tableView addSubview:refreshControl];
    
    [self updateNodes];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    _threadViewController = nil;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_nodes.count) {
        
        [self.refreshControl beginRefreshing];
        [self doRefresh:nil];
        
    } else if (self.tableView.indexPathForSelectedRow && _storeNodeInfo.treeNumRecent >= 0) {
        
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        
        VifNode *node = _nodes[indexPath.row];
        
        if (_storeNodeInfo.treeNumRecent != node.tree.numRecent ||
            _storeNodeInfo.treeHasUnread != node.tree.hasUnread ||
            _storeNodeInfo.nodeIsUnread != node.isUnread) {
        
            DDLogVerbose(@"reload node at %@", self.tableView.indexPathForSelectedRow);
            
            [self.tableView reloadRowsAtIndexPaths:@[indexPath ]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            
        }
    }
}

#pragma mark - public

- (BOOL) openArticle: (NSUInteger) number
{
    UIViewController *vc = self.navigationController.topViewController;
    if (vc != self) {
        
        if (vc == _threadViewController &&
            [_threadViewController openArticle: number])
            return YES;
        
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    
    for (VifNode *node in _nodes) {
        if (node.article.number == number) {
            
            [self showThread:node];
            return YES;
        }
        
        if ([node.tree findNode:number recursive:YES]) {
            
            [self showThread:node];

            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                
                [_threadViewController openArticle: number];
            });
            
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - private

- (void) showThread: (VifNode *) node
{
    if (!_threadViewController) {
        _threadViewController = [[ThreadViewController alloc] init];
    }
    
    _storeNodeInfo.treeNumRecent = node.tree.numRecent;
    _storeNodeInfo.treeHasUnread = node.tree.hasUnread;
    _storeNodeInfo.nodeIsUnread = node.isUnread;
    
    _threadViewController.rootNode = node;
    [self.navigationController pushViewController:_threadViewController animated:YES];
}

- (void) updateNodes
{
    _nodes = [VifModel model].sortedNodes;  
    _threadViewController = nil;
}

- (void)doRefresh:(CKRefreshControl *)sender
{
    [VifModel.model asyncUpdate:^(id result) {
 
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
        
            [self updateNodes];
            [self.tableView reloadData];
            _storeNodeInfo.treeNumRecent = -1;
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VifNode *node = _nodes[indexPath.row];
    
    return [VifNodeCell heightForNode:node
                                 text:nil
                           htmlRender:nil
                            withWidth:self.cellWidth];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _nodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VifNode *node = _nodes[indexPath.row];
    
    VifNodeCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"VifNodeCell"];
    if (cell == nil) {
        
        cell = [[VifNodeCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:@"VifNodeCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.node = node;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    VifNode *node = _nodes[indexPath.row];
    [self showThread:node];   
}

@end
