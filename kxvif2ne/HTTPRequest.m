//
//  FileDownloader.m
//  kxtorrent
//
//  Created by Kolyvan on 24.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxvif2ne
//  this file is part of kxvif2ne
//  kxvif2ne is licenced under the LGPL v3, see lgpl-3.0.txt
//

#import "HTTPRequest.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

#define FAKE_USER_AGENT @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206"


static NSString * extractContentValueAndField(NSString * string, NSString * nameField, NSString **fieldValue)
{
    NSArray *a = [string componentsSeparatedByString:@";"];
    if (!a.count)
        return nil;
    
    if (nameField && fieldValue) {
        
        nameField = [NSString stringWithFormat:@"%@=", nameField];
        
        for (NSUInteger i = 1; i < a.count; ++i) {
            
            NSString *s = a[i];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([s hasPrefix:nameField]) {
                s = [s substringFromIndex:nameField .length];
                if (s.length > 2) {
                    if ([s characterAtIndex:0] == '"')
                        s = [s substringFromIndex:1];
                    if ([s characterAtIndex:s.length - 1] == '"')
                        s = [s substringToIndex:s.length - 1];
                    *fieldValue = s;
                }
                break;
            }
        }
    }
    
    return a[0];
}

////////

@interface HTTPRequestResponse()
@property (readwrite, nonatomic) NSUInteger statusCode;
@property (readwrite, nonatomic) NSUInteger contentLength;
@property (readwrite, nonatomic, strong) NSDictionary *responseHeaders;
//@property (readwrite, nonatomic, strong) NSString *mimeType;
@end

@implementation HTTPRequestResponse

- (id) initWithResponse: (NSHTTPURLResponse *) response
{
    self = [super init];
    if (self) {
        
        DDLogVerbose(@"response %d", response.statusCode);
        //NSDictionary * d = response.allHeaderFields;
        //[d enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        //    DDLogVerbose(@"  %@: %@", key, obj);
        //}];
        
        _statusCode = response.statusCode;
        _responseHeaders = response.allHeaderFields;
        
        /*
        NSString *contentType = [_responseHeaders valueForKey:@"Content-Type"];
        if (contentType) {
            
            NSString *s = nil;
            _mimeType = extractContentValueAndField(contentType, @"name", _fileName ? nil : &s);
            if (!_fileName)
                _fileName = s;
        }
        */ 

        _contentLength = [response expectedContentLength];
    }
    
    return self;
}

@end

////////

@implementation HTTPRequest {

    NSURLConnection             *_conn;
    HTTPRequestResponseBlock    _response;
    HTTPRequestProgressBlock    _progress;
    HTTPRequestCompleteBlock    _complete;
    NSMutableData               *_data;
    NSUInteger                  _bytesReceived;
}

+ (id) httpGet: (NSURL *) url
       referer: (NSString *) referer
 authorization: (NSString *) authorization
      response: (HTTPRequestResponseBlock) response
      progress: (HTTPRequestProgressBlock) progress
      complete: (HTTPRequestCompleteBlock) complete
{
    return [[HTTPRequest alloc] initHttpGet: url
                                    referer: referer
                              authorization: authorization            
                                   response: response
                                   progress: progress
                                   complete: complete];
}

- (id)  initHttpGet: (NSURL *) url
            referer: (NSString *) referer
      authorization: (NSString *) authorization
           response: (HTTPRequestResponseBlock) response
           progress: (HTTPRequestProgressBlock) progress
           complete: (HTTPRequestCompleteBlock) complete
{
    self = [super init];
    if (self) {
        
        _response = response;
        _progress = progress;
        _complete = complete;
        _url = url;
        
        NSDictionary *dict = @{
        @"User-Agent"       : FAKE_USER_AGENT,
        @"DNT"              : @"1",
        @"Accept-Language"  : @"ru-RU, ru, en-US;q=0.8",
        @"Pragma"           : @"no-cache",
        @"Cache-Control"    : @"no-cache, max-age=0",
        @"Proxy-Connection" : @"keep-alive",
        };
        
        //@"Accept-Encoding": @"gzip, deflate",
        
        NSMutableDictionary *md = [dict mutableCopy];
        if (referer)
            md[@"Referer"] = referer;
        if (authorization)
            md[@"Authorization"] = authorization;
        
        DDLogVerbose(@"get %@ auth: %@", _url, authorization);
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_url];
        [request setHTTPMethod:@"GET"];
        [request setAllHTTPHeaderFields:md];
        [request setHTTPShouldHandleCookies: YES];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
                
        _conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        if (!_conn) {
            
            DDLogWarn(@"connection '%@' can't be initialized", url);
            self = nil;
        }
    }
    return self;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_conn) {
        
        [_conn cancel];
        _conn = nil;
    }
    
    _data = nil;
}

- (BOOL) isClosed
{
    return _conn == nil;
}

- (void) closeWithSuccess
{    
    if (_complete)
        _complete(self, _data, nil);
    
    [self close];
}

- (void) closeWithError: (NSError *) error
{
    DDLogWarn(@"connection '%@' failed: %@", _url, error);
    
    if (_complete)
        _complete(self, nil, error);
    
    [self close];
}

#pragma mark - NSURLConnection delegate;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _data = [NSMutableData data];
        
    if (_response) {
    
        HTTPRequestResponse *r = nil;
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
            r = [[HTTPRequestResponse alloc] initWithResponse:(NSHTTPURLResponse *)response];
        
        if (!_response(self, r)) {
            
            [self close];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
    _bytesReceived += data.length;
    
    if (_progress &&
        !_progress(self, _bytesReceived)) {

        [self close];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self closeWithError: error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{   
    [self closeWithSuccess];
}

@end
