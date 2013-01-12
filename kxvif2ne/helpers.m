//
//  helpers.m
//  kxvif2ne
//
//  Created by Kolyvan on 29.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "helpers.h"

NSString *fixAmpersandsInString(NSString *string)
{
    if ([string rangeOfString:@"&"].location == NSNotFound)
        return string;
    
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:nil];
    
    while (!scanner.isAtEnd) {
        
        NSString *s;
        
        if ([scanner scanUpToString:@"&" intoString:&s])
            [ms appendString:s];
                
        if (![scanner scanString:@"&" intoString:nil])
            break;
        
        NSUInteger scanLoc = scanner.scanLocation;
        
        if ([scanner scanUpToString:@";" intoString:&s]) {
            
            if ([scanner scanString:@";" intoString:nil]) {
            
                // ok it maybe valid html sybmol
                
                [ms appendString:@"&"];
                [ms appendString:s];
                [ms appendString:@";"];

            } else {
                
                // broken format URL
                // http://tools.ietf.org/html/rfc3986#section-2.2
                
                // replace ampersand with html sybmol
                [ms appendString:@"&amp;"];
                
                scanner.scanLocation = scanLoc;
            }
        }
    }
    
    return ms;
}

NSString *fixBrokenURLInHTML(NSString *html)
{
    if ([html rangeOfString:@"<a"].location == NSNotFound)
        return html;
    
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:html];
    [scanner setCharactersToBeSkipped:nil];
    
    while (!scanner.isAtEnd) {
        
        NSString *s;
        
        if ([scanner scanUpToString:@"<a" intoString:&s])
            [ms appendString:s];
               
        if (![scanner scanString:@"<a" intoString:nil])
            break;
        
        if ([scanner scanUpToString:@"</a>" intoString:&s]) {
            
            [ms appendString:@"<a"];
            
            if ([scanner scanString:@"</a>" intoString:nil]) {
            
                [ms appendString: fixAmpersandsInString(s)];
                [ms appendString:@"</a>"];
                
            } else {
                
                [ms appendString:s];
            }
        }
    }
    
    return ms;
}

NSData *fixBrokenTitleInXML(NSData *xml)
{
    NSString *sxml = [[NSString alloc] initWithData:xml encoding:NSWindowsCP1251StringEncoding];
    
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:sxml];
    [scanner setCharactersToBeSkipped:nil];
    
    while (!scanner.isAtEnd) {
        
        NSString *s;
        
        if ([scanner scanUpToString:@"<title>" intoString:&s])
            [ms appendString:s];
        
        if (![scanner scanString:@"<title>" intoString:nil])
            break;
        
        if ([scanner scanUpToString:@"</title>" intoString:&s]) {
            
            [ms appendString:@"<title>"];
            
            if ([scanner scanString:@"</title>" intoString:nil]) {
                
                [ms appendString: fixAmpersandsInString(s)];
                [ms appendString:@"</title>"];
                
            } else {

                [ms appendString:s];
            }
        }
    }
    
    return [ms dataUsingEncoding:NSWindowsCP1251StringEncoding];
}

void drainCacheIfExcess(NSMutableDictionary *cache, NSUInteger maxSize)
{
    NSUInteger size = 0;
    for (id p in cache.allValues) {
        if ([p isKindOfClass:[NSData class]]) {
            size +=  ((NSData *)p).length;
            if (size > maxSize) {
                [cache removeAllObjects];
                break;
            }
        }
    }
}

NSString *stripHTMLComment(NSString *html)
{    
    if ([html rangeOfString:@"<!--"].location == NSNotFound)
        return html;
    
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:html];
    [scanner setCharactersToBeSkipped:nil];
    
    while (!scanner.isAtEnd) {
        
        NSString *s;
        
        if ([scanner scanUpToString:@"<!--" intoString:&s])
            [ms appendString:s];
        
        if (![scanner scanString:@"<!--" intoString:nil])
            break;
        
        [scanner scanUpToString:@"-->" intoString:nil];
        if (![scanner scanString:@"-->" intoString:nil])
            break;
    }
    
    return ms;
}

NSString *stripHTMLTags(NSString *html)
{    
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:html];
    [scanner setCharactersToBeSkipped:nil];
    
    while (!scanner.isAtEnd) {
        
        NSString *s, *tag = nil;
        
        if ([scanner scanUpToString:@"<" intoString:&s])
            [ms appendString:s];
        
        if (![scanner scanString:@"<" intoString:nil])
            break;
                
        if ([scanner scanUpToString:@">" intoString:&tag] &&
            [scanner scanString:@">" intoString:nil]) {
        
            tag = tag.lowercaseString;
            
            if ([tag isEqualToString:@"br"] ||
                [tag isEqualToString:@"p"] ||
                [tag isEqualToString:@"div"] ||
                [tag isEqualToString:@"blockquote"]) {
                
                [ms appendString:@"\n"];
            }
            
        } else {
                
            [ms appendString:@"<"];
            if (tag.length)
                [ms appendString:tag];
        }
    }
    
    return ms;
}

NSUInteger parseIntegerValueFromHex(NSString *hex)
{
    NSUInteger result = 0;
    NSScanner* scanner = [NSScanner scannerWithString:hex];
    [scanner scanHexInt:&result];
    return result;
}