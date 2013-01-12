//
//  ArticleCell.m
//  kxvif2ne
//
//  Created by Kolyvan on 27.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "ArticleCell.h"
#import "ColorTheme.h"
#import "UIFont+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "VifModel.h"
#import "KxHTML.h"
#import "AppDelegate.h"

@implementation VifNodeCell

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        
        ColorTheme *theme = [ColorTheme theme];
        self.backgroundColor = theme.backgroundColor;
        
        self.backView.opaque = NO;
        self.backView.backgroundColor = [UIColor clearColor];
		self.contentView.opaque = NO;
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

+ (CGFloat) heightForNode:(VifNode *) node
                     text:(NSString *)text
               htmlRender:(KxHTMLRender *)htmlRender
                withWidth:(CGFloat) width
{
    VifArticle *article = node.article;
    const BOOL expanded = (text != nil || htmlRender != nil);
    
    width -= 10;
    
    float H = [UIFont boldSystemFont14].lineHeight;
    H += 2;
    
    H += [article.title sizeWithFont:expanded ? [UIFont systemFont12] : [UIFont systemFont14]
                   constrainedToSize:CGSizeMake(width, 9999)
                       lineBreakMode:NSLineBreakByWordWrapping].height;
    H += 2;
    
    if (expanded) {
        
        if (text) {
            
            H +=  [text sizeWithFont:[UIFont systemFont14]
                   constrainedToSize:CGSizeMake(width, 9999)
                       lineBreakMode:NSLineBreakByWordWrapping].height;
        } else {
            
            H += [htmlRender layoutWithWidth:width];
        }        
        H += 2;
    }
    
    H += [UIFont systemFont12].lineHeight;
    
    return H + 10;
}

- (void)drawContentView:(CGRect)r
{
    VifArticle *article = _node.article;
        
    ColorTheme *theme = [ColorTheme theme];
    
    CGRect bounds = self.contentView.bounds;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    //[theme.backgroundColor set];
	//CGContextFillRect(context, bounds);
    
    const BOOL expanded = (_text != nil || _htmlRender != nil);
    
    CGFloat margin = 0;
    
    if (!expanded) {
        
        margin = self.indentationLevel * self.indentationWidth;        
        bounds.origin.x     += margin;
        bounds.size.width   -= margin;
    }
    
    CGFloat H = bounds.size.height - 10;
    CGFloat W = bounds.size.width - 10;
    CGFloat X = bounds.origin.x + 5, Y = bounds.origin.y + 5;
        
    CGSize size;
    	   
    // draw author
    [theme.altTextColor set];
    size = [article.author drawAtPoint:CGPointMake(X, Y)
                              forWidth:W
                              withFont:[UIFont boldSystemFont14]
                         lineBreakMode:NSLineBreakByClipping];
    
    // draw articel number
    if (expanded)
    {
        [[theme.grayedTextColor colorWithAlphaComponent:0.3] set];
        
        NSString *s = [NSString stringWithFormat:@"%d", article.number];
        const float w = [s sizeWithFont:[UIFont systemFont12]
                               forWidth:W
                          lineBreakMode:NSLineBreakByClipping].width;
        
        [s drawAtPoint:CGPointMake(X + W - w, Y + 2)
              forWidth:w
              withFont:[UIFont systemFont12]
         lineBreakMode:NSLineBreakByClipping];
    }
    
    Y += size.height + 2;
    H -= size.height + 2;
    
    // draw title
        
    if (expanded)
        [theme.grayedTextColor set];
    else
        [theme.textColor set];
    
    size = [article.title drawInRect:CGRectMake(X, Y, W, H)
                            withFont:expanded ? [UIFont systemFont12] : [UIFont systemFont14]
                       lineBreakMode:NSLineBreakByWordWrapping];
        
    Y += size.height + 2;
    H -= size.height + 2;
    
    if (expanded) {
        
        if (_text) {
                    
            [theme.textColor set];
            size = [_text drawInRect:CGRectMake(X, Y, W, H)
                            withFont:[UIFont systemFont14]
                       lineBreakMode:NSLineBreakByWordWrapping];
            
        
        } else {
            
            size.height = [_htmlRender drawInRect:CGRectMake(X, Y, W, H)
                                          context:context];
            
        }
        
        Y += size.height + 2;
        //H -= size.height + 2;
    }
    
    // draw info
    
    NSString *info = [NSString stringWithFormat:@"%@, %d байт",
                   article.date.shortRelativeFormatted, article.size];
    
    if (_node.isRecent)
        [theme.highlightTextColor set];
    else if (_node.isUnread)
        [theme.altTextColor set];
    else
        [theme.grayedTextColor set];
    
    
    size = [info drawAtPoint:CGPointMake(X, Y)
                    forWidth:W //size.width
                    withFont:[UIFont systemFont12]
               lineBreakMode:NSLineBreakByClipping];
    
    
    // draw replies
    
    if (_node.tree.numReplies) {
        
        float dW = 0;
                
        const NSUInteger numRecent = _node.tree.numRecent;
        
        if (numRecent) {
            
            NSString *s = [NSString stringWithFormat:@"+%d", numRecent];
            
            size = [s sizeWithFont:[UIFont systemFont12]
                          forWidth:W
                     lineBreakMode:NSLineBreakByClipping];
            
            [theme.highlightTextColor set];
            
            [s drawAtPoint:CGPointMake(X + W - size.width, Y - 2)
                  forWidth:size.width
                  withFont:[UIFont systemFont12]
             lineBreakMode:NSLineBreakByClipping];
            
            dW = size.width + 1;
        }
                            
        NSString *s = [NSString stringWithFormat:@"%d", _node.tree.numReplies];
        
        size = [s sizeWithFont:[UIFont boldSystemFont14]
                      forWidth:W
                 lineBreakMode:NSLineBreakByClipping];
        
        if (numRecent)            
            [theme.altTextColor set];
        else if (_node.tree.hasUnread)
            [theme.altTextColor set];
        else
            [theme.grayedTextColor set];
        
        [s drawAtPoint:CGPointMake(X + W - dW - size.width, Y - 2)
              forWidth:size.width
              withFont:[UIFont boldSystemFont14]
         lineBreakMode:NSLineBreakByClipping];
    }
  
    if (margin > 0) {

        const CGRect r = self.contentView.bounds;
        const CGFloat h = r.size.height;
        const CGFloat x = r.origin.x + 4;
        const CGFloat y = r.origin.y + h * 0.5;
        
        CGContextSetLineWidth(context, 8);
        CGContextSetStrokeColorWithColor(context,
                                         [theme.grayedTextColor colorWithAlphaComponent:0.2].CGColor);
        CGFloat lineDash[] = {self.indentationWidth - 2, 2};
        CGContextSetLineDash(context, 0, lineDash, sizeof(lineDash)/sizeof(CGFloat));
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint(context, x + margin, y);
        CGContextStrokePath(context);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *t = [touches anyObject];
    if ([t tapCount] == 1) {
        
        CGPoint loc = [t locationInView:self];
        [self handleTouch: loc];
    }

    [super touchesEnded:touches withEvent:event];
}

- (BOOL) handleTouch: (CGPoint) loc
{
    const BOOL expanded = (_text != nil || _htmlRender != nil);
    if (expanded) {
        
        if (CGRectContainsPoint(CGRectMake(self.bounds.size.width - 50, 10, 50, 20), loc)) {
            
            NSString *s = [NSString stringWithFormat:@"http://vif2ne.ru/nvk/forum/0/co/%d.htm",
                           _node.article.number];
            NSURL *url = [NSURL URLWithString:s];
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [appDelegate openURLInWebBrowserController:url];
            return YES;
        }
    }
    
    if (_htmlRender && _htmlRender.isUserInteractive) {
    
        if (CGRectContainsPoint([self bounds], loc)) {
            
            NSURL *url = [_htmlRender hitTest:loc];
            if (url) {
                
                UIApplication *app = [UIApplication sharedApplication];
                if ([app.delegate respondsToSelector:@selector(application:handleOpenURL:)]) {
                    
                    if ([app.delegate application:app handleOpenURL: url])
                        return YES;
                }
                
                if ([app canOpenURL:url]) {
                    [app openURL:url];
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

@end
