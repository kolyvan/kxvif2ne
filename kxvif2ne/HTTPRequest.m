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

static int ddLogLevel = LOG_LEVEL_VERBOSE;

#define FAKE_USER_AGENT @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206"


static NSString * extractContentValueAndField(NSString *string, NSString *nameField, NSString **fieldValue)
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

static NSString * htmlBodyFromParameters(NSDictionary *dict, CFStringEncoding encoding)
{
    static NSString *escaped = @"?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ ";
        
    NSMutableArray *ma = [NSMutableArray array];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
      
        CFStringRef cref = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                   (CFStringRef)[val description],
                                                                   NULL,
                                                                   (CFStringRef)escaped,
                                                                   encoding);
        
        NSString *s  = [NSString stringWithFormat:@"%@=%@", key, cref];
        [ma addObject:s];
    }];
    return [ma componentsJoinedByString:@"&"];
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
        
        _statusCode = response.statusCode;
        _responseHeaders = response.allHeaderFields;
        _stringEncoding = NSWindowsCP1251StringEncoding;
        
        NSString *contentType = [_responseHeaders valueForKey:@"Content-Type"];
        if (contentType) {
            NSString *charset;
            _mimeType = extractContentValueAndField(contentType, @"charset", &charset);
            _charset = charset;
            
            if (_charset.length) {
                
                CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)_charset);
                if (encoding != kCFStringEncodingInvalidId)
                    _stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);                
            }
        }

        _contentLength = [response expectedContentLength];
        
        DDLogVerbose(@"response %d %d %@ %@ %d",
                     response.statusCode, _contentLength, _mimeType, _charset, _stringEncoding);
        //[response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        //    DDLogVerbose(@"  %@: %@", key, obj);
        //}];
    }
    return self;
}

@end

////////

@implementation HTTPRequest {

    NSURLConnection             *_conn;
    HTTPRequestResponseBlock    _responseBlock;
    HTTPRequestProgressBlock    _progressBlock;
    HTTPRequestCompleteBlock    _completeBlock;
    NSMutableData               *_data;
    NSUInteger                  _bytesReceived;
}

+ (id) httpGet: (NSURL *) url
       referer: (NSString *) referer
 authorization: (NSString *) authorization
      response: (HTTPRequestResponseBlock) responseBlock
      progress: (HTTPRequestProgressBlock) progressBlock
      complete: (HTTPRequestCompleteBlock) completeBlock
{
    return [[HTTPRequest alloc] initHttpGet: url
                                    referer: referer
                              authorization: authorization            
                                   response: responseBlock
                                   progress: progressBlock
                                   complete: completeBlock];
}

+ (id) httpPost: (NSURL *) url
        referer: (NSString *) referer
  authorization: (NSString *) authorization
     parameters: (NSDictionary *) parameters
       encoding: (NSStringEncoding) encoding
       response: (HTTPRequestResponseBlock) responseBlock
       progress: (HTTPRequestProgressBlock) progressBlock
       complete: (HTTPRequestCompleteBlock) completeBlock
{
    return [[HTTPRequest alloc] initHttpPost: url
                                     referer: referer
                               authorization: authorization
                                  parameters:parameters
                                    encoding: encoding
                                    response: responseBlock
                                    progress: progressBlock
                                    complete: completeBlock];
}

- (id)  initHttpGet: (NSURL *) url
            referer: (NSString *) referer
      authorization: (NSString *) authorization
           response: (HTTPRequestResponseBlock) responseBlock
           progress: (HTTPRequestProgressBlock) progressBlock
           complete: (HTTPRequestCompleteBlock) completeBlock
{
    self = [super init];
    if (self) {
        
        _responseBlock = responseBlock;
        _progressBlock = progressBlock;
        _completeBlock = completeBlock;
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
        
        DDLogVerbose(@"get %@", _url);
        
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

- (id)  initHttpPost: (NSURL *) url
             referer: (NSString *) referer
       authorization: (NSString *) authorization
          parameters: (NSDictionary *) parameters
            encoding: (NSStringEncoding) encoding
            response: (HTTPRequestResponseBlock) responseBlock
            progress: (HTTPRequestProgressBlock) progressBlock
            complete: (HTTPRequestCompleteBlock) completeBlock
{
    self = [super init];
    if (self) {
        
        _responseBlock = responseBlock;
        _progressBlock = progressBlock;
        _completeBlock = completeBlock;
        _url = url;
        
        NSDictionary *dict = @{
        @"User-Agent"       : FAKE_USER_AGENT,
        @"DNT"              : @"1",
        @"Accept-Language"  : @"ru-RU, ru, en-US;q=0.8",
        @"Pragma"           : @"no-cache",
        @"Cache-Control"    : @"no-cache, max-age=0",
        @"Proxy-Connection" : @"keep-alive",
        };
        
        NSMutableDictionary *md = [dict mutableCopy];
        
        if (referer)
            md[@"Referer"] = referer;
        if (authorization)
            md[@"Authorization"] = authorization;
        
        NSData *body = nil;
        if (parameters.count) {
            
            CFStringEncoding cfsEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
            NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(cfsEncoding);
            DDLogVerbose(@"charset %@", charset);            
            md[@"Content-Type"] = [NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset];
            body = [htmlBodyFromParameters(parameters, cfsEncoding) dataUsingEncoding:encoding];
        }
        
        DDLogVerbose(@"post %@ auth: %@", _url, authorization);
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_url];
        [request setHTTPMethod:@"POST"];
        [request setAllHTTPHeaderFields:md];
        [request setHTTPShouldHandleCookies: YES];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];        
        if (body)
            [request setHTTPBody:body];
        
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
    if (_completeBlock)
        _completeBlock(self, _data, nil);
    
    [self close];
}

- (void) closeWithError: (NSError *) error
{
    DDLogWarn(@"connection '%@' failed: %@", _url, error);
    
    if (_completeBlock)
        _completeBlock(self, nil, error);
    
    [self close];
}

#pragma mark - NSURLConnection delegate;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _data = [NSMutableData data];
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]])
        _response = [[HTTPRequestResponse alloc] initWithResponse:(NSHTTPURLResponse *)response];
    
    if (_responseBlock && !_responseBlock(self)) {
        
        [self close];
    }    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
    _bytesReceived += data.length;
    
    if (_progressBlock &&
        !_progressBlock(self, _bytesReceived)) {

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
