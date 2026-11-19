#import "HTTPRequestParser.h"

#if TARGET_OS_OSX


#import <CFNetwork/CFNetwork.h>


static const NSUInteger maxHeaderLength = 16 * 1024;
static const NSUInteger maxBodyLength = 1024 * 1024;


@implementation HTTPRequest


- (instancetype)initWithMethod:(NSString *)method
                          path:(NSString *)path
                     userAgent:(nullable NSString *)userAgent
                   contentType:(nullable NSString *)contentType
              hasContentLength:(BOOL)hasContentLength
                          body:(NSData *)body
              closesConnection:(BOOL)closesConnection;
{
    self = [super init];
    if (!self) return nil;

    _method = [method copy];
    _path = [path copy];
    _userAgent = [userAgent copy];
    _contentType = [contentType copy];
    _hasContentLength = hasContentLength;
    _body = [body copy];
    _closesConnection = closesConnection;

    return self;
}


@end


static NSString *_Nullable header_value(
    CFHTTPMessageRef message, NSString *name)
{
    return CFBridgingRelease(
        CFHTTPMessageCopyHeaderFieldValue(message, (__bridge CFStringRef)name));
}


static BOOL is_decimal_number(NSString *text)
{
    NSCharacterSet *nonDigits =
        NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    return text.length > 0 && text.length <= 10 &&
        [text rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}


@implementation HTTPRequestParser {
    CFHTTPMessageRef _message;
    NSUInteger _lengthAppended;
    BOOL _hasParsedHeader;
    NSString *_method;
    NSString *_path;
    NSString *_userAgent;
    NSString *_contentType;
    BOOL _hasContentLength;
    NSUInteger _bodyLength;
    BOOL _closesConnection;
}


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _message = CFHTTPMessageCreateEmpty(NULL, true);
    _excessData = [NSData data];

    return self;
}


- (void)dealloc;
{
    CFRelease(_message);
}


- (void)append:(NSData *)data;
{
    if (HTTPRequestParserStateIncomplete != _state) return;

    _lengthAppended += data.length;
    if (!CFHTTPMessageAppendBytes(_message, data.bytes, data.length)) {
        _state = HTTPRequestParserStateInvalid;
        return;
    }
    if (!CFHTTPMessageIsHeaderComplete(_message)) {
        if (_lengthAppended > maxHeaderLength) {
            _state = HTTPRequestParserStateInvalid;
        }
        return;
    }

    NSData *received = [self receivedBody];
    if (!_hasParsedHeader) {
        _hasParsedHeader = YES;
        NSUInteger headerLength = _lengthAppended - received.length;
        if (headerLength > maxHeaderLength || ![self parseHeader]) {
            _state = HTTPRequestParserStateInvalid;
            return;
        }
    }
    if (received.length < _bodyLength) return;

    NSData *body = [received subdataWithRange:NSMakeRange(0, _bodyLength)];
    _excessData =
        [received subdataWithRange:NSMakeRange(_bodyLength,
                                       received.length - _bodyLength)];
    _request = [[HTTPRequest alloc] initWithMethod:_method
                                              path:_path
                                         userAgent:_userAgent
                                       contentType:_contentType
                                  hasContentLength:_hasContentLength
                                              body:body
                                  closesConnection:_closesConnection];
    _state = HTTPRequestParserStateComplete;
}


// CFHTTPMessageCopyBody() returns NULL rather than empty data when no bytes
// have followed the header.
- (NSData *)receivedBody;
{
    NSData *body = CFBridgingRelease(CFHTTPMessageCopyBody(_message));
    return body ?: [NSData data];
}


- (BOOL)parseHeader;
{
    _method = CFBridgingRelease(CFHTTPMessageCopyRequestMethod(_message));
    NSURL *url = CFBridgingRelease(CFHTTPMessageCopyRequestURL(_message));
    _path = url.path;
    NSString *version = CFBridgingRelease(CFHTTPMessageCopyVersion(_message));
    BOOL isHTTP10 = [version isEqual:(__bridge NSString *)kCFHTTPVersion1_0];
    BOOL isHTTP11 = [version isEqual:(__bridge NSString *)kCFHTTPVersion1_1];
    if (!_method.length || !_path.length || !(isHTTP10 || isHTTP11)) return NO;

    NSString *userAgent = header_value(_message, @"User-Agent");
    _userAgent = userAgent.length ? userAgent : nil;
    _contentType = header_value(_message, @"Content-Type");

    NSString *connection = header_value(_message, @"Connection");
    BOOL asksToClose = connection &&
        [connection rangeOfString:@"close" options:NSCaseInsensitiveSearch]
                .location
            != NSNotFound;
    _closesConnection = isHTTP10 || asksToClose;

    return [self parseBodyLength];
}


// Chunked request bodies are not supported, so any transfer encoding is
// rejected rather than misread as the start of the next request.
- (BOOL)parseBodyLength;
{
    if (header_value(_message, @"Transfer-Encoding")) return NO;

    NSString *contentLength = header_value(_message, @"Content-Length");
    if (!contentLength) return YES;
    if (!is_decimal_number(contentLength)) return NO;

    _hasContentLength = YES;
    _bodyLength = (NSUInteger)contentLength.longLongValue;
    return _bodyLength <= maxBodyLength;
}


@end


#endif
