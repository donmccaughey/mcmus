#import "HTTPResponse.h"

#if TARGET_OS_OSX


#import <CFNetwork/CFNetwork.h>


static NSString *status_description(HTTPStatus status)
{
    switch (status) {
    case HTTPStatusOK: return @"OK";
    case HTTPStatusBadRequest: return @"Bad Request";
    case HTTPStatusNotFound: return @"Not Found";
    case HTTPStatusMethodNotAllowed: return @"Method Not Allowed";
    case HTTPStatusTooManyRequests: return @"Too Many Requests";
    case HTTPStatusServiceUnavailable: return @"Service Unavailable";
    }
}


static void set_header(
    CFHTTPMessageRef message, NSString *name, NSString *value)
{
    CFHTTPMessageSetHeaderFieldValue(
        message, (__bridge CFStringRef)name, (__bridge CFStringRef)value);
}


NSData *makeHTTPResponse(HTTPStatus status, NSString *contentType, NSData *body,
    BOOL closesConnection)
{
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(NULL, status,
        (__bridge CFStringRef)status_description(status), kCFHTTPVersion1_1);
    set_header(message, @"Content-Type", contentType);
    set_header(message, @"Content-Length",
        [NSString stringWithFormat:@"%lu", body.length]);
    if (closesConnection) set_header(message, @"Connection", @"close");
    CFHTTPMessageSetBody(message, (__bridge CFDataRef)body);

    NSData *response =
        CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    CFRelease(message);
    return response;
}


NSData *makeHTTPTextResponse(
    HTTPStatus status, NSString *text, BOOL closesConnection)
{
    return makeHTTPResponse(status, @"text/plain;charset=UTF-8",
        [text dataUsingEncoding:NSUTF8StringEncoding], closesConnection);
}


#endif
