//
//  XmlReader.m
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "XmlReader.h"

NSString *XMLReaderTextNodeKey = @"XMLReaderTextNodeKey";

@interface XmlReader()
@property (readonly, nonatomic, strong) NSMutableArray *stack;
@property (readonly, nonatomic, strong) NSMutableString *text;
@property (readonly, nonatomic, strong) NSError *parseError;
@end

@implementation XmlReader

+ (NSDictionary *) read: (NSData *)xml
                  error: (NSError **)error
{
    XmlReader *reader = [[XmlReader alloc] init];
        
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xml];
    parser.shouldProcessNamespaces = NO;
    parser.shouldReportNamespacePrefixes = NO;
    parser.shouldResolveExternalEntities = NO;
    parser.delegate = reader;
    
    NSDictionary *result = nil;
    
    if ([parser parse] && reader.stack.count)
        result = reader.stack[0];
    
    if (error)
        *error = reader.parseError;
    
    return result;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        _text = [NSMutableString string];
        _stack = [NSMutableArray array];
        [_stack addObject:[NSMutableDictionary dictionary]];
    }
    return self;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    NSMutableDictionary *parent = _stack.lastObject;

    NSMutableDictionary *child = [NSMutableDictionary dictionary];
    [child addEntriesFromDictionary:attributeDict];

    id value = [parent objectForKey:elementName];
    if (value) {
        
        NSMutableArray *ma = nil;
        if ([value isKindOfClass:[NSMutableArray class]]) {
            
            ma = (NSMutableArray *)value;
            
        } else {
            
            ma = [NSMutableArray array];
            [ma addObject:value];
            [parent setValue:ma forKey:elementName];
        }

        [ma addObject:child];
        
    } else {
        
        [parent setValue:child forKey:elementName];
    }
        
    [_stack addObject:child];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    NSMutableDictionary *dict = _stack.lastObject;
    [_stack removeLastObject];

    if (dict.count == 0) {
        
        id parent = _stack.lastObject;
        if ([parent isKindOfClass:[NSMutableArray class]]) {
            
            [((NSMutableArray *)parent) removeObject:dict];
            [((NSMutableArray *)parent) addObject:_text];
            
        } else {
            
            [((NSMutableDictionary *)parent) removeObjectForKey:elementName];
            [((NSMutableDictionary *)parent) setValue:_text forKey:elementName];
        }
        
    } else {
    
        if (_text.length)
            [dict setObject:_text forKey:XMLReaderTextNodeKey];
    }

    _text = [[NSMutableString alloc] init];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (string.length == 1 && [string characterAtIndex:0] == '\n') {
        
        // NSLog(@"foundCharacters:SKIP CR");
        
    } else {
        
        [_text appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSLog(@"parseErrorOccurred %d:%d %@", parser.lineNumber, parser.columnNumber, parseError);
    _parseError = parseError;
}

- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validError
{
    NSLog(@"validationErrorOccurred %d:%d %@", parser.lineNumber, parser.columnNumber, validError);
}

@end