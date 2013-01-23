//
//  FileDownloader.h
//  kxtorrent
//
//  Created by Kolyvan on 24.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import <Foundation/Foundation.h>

@class HTTPRequest;

@interface HTTPRequestResponse : NSObject
@property (readonly, nonatomic) NSUInteger statusCode;
@property (readonly, nonatomic) NSUInteger contentLength;
@property (readonly, nonatomic, strong) NSDictionary *responseHeaders;
@property (readonly, nonatomic, strong) NSString *mimeType;
@property (readonly, nonatomic, strong) NSString *charset;
@property (readonly, nonatomic) NSStringEncoding stringEncoding;
@end

typedef BOOL (^HTTPRequestResponseBlock)(HTTPRequest*);
typedef BOOL (^HTTPRequestProgressBlock)(HTTPRequest*, NSUInteger bytesReceived);
typedef void (^HTTPRequestCompleteBlock)(HTTPRequest*, NSData*, NSError*);

@interface HTTPRequest: NSObject<NSURLConnectionDelegate>

@property (readonly, nonatomic, strong) NSURL *url;
@property (readonly, nonatomic, strong) HTTPRequestResponse *response;

+ (id) httpGet: (NSURL *) url
       referer: (NSString *) referer
 authorization: (NSString *) authorization
      response: (HTTPRequestResponseBlock) response
      progress: (HTTPRequestProgressBlock) progress
      complete: (HTTPRequestCompleteBlock) complete;

+ (id) httpPost: (NSURL *) url
        referer: (NSString *) referer
  authorization: (NSString *) authorization
     parameters: (NSDictionary *) parameters
       encoding: (NSStringEncoding) encoding
       response: (HTTPRequestResponseBlock) response
       progress: (HTTPRequestProgressBlock) progress
       complete: (HTTPRequestCompleteBlock) complete;

- (void) close;

- (BOOL) isClosed;

@end
