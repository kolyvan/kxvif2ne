//
//  XmlReader.h
//  kxvif2ne
//
//  Created by Kolyvan on 12.12.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

extern NSString *XMLReaderTextNodeKey;

@interface XmlReader : NSObject<NSXMLParserDelegate>

+ (NSDictionary *) read: (NSData *)xml
                  error: (NSError **)error;

@end
