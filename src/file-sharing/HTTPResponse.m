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
    case HTTPStatusInternalServerError: return @"Internal Server Error";
    case HTTPStatusServiceUnavailable: return @"Service Unavailable";
    }
}


static void set_header(
    CFHTTPMessageRef message, NSString *name, NSString *value
)
{
    CFHTTPMessageSetHeaderFieldValue(
        message, (__bridge CFStringRef)name, (__bridge CFStringRef)value
    );
}


static CFHTTPMessageRef create_response_message(
    HTTPStatus status,
    NSString *contentType,
    unsigned long long contentLength,
    BOOL closesConnection
)
{
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(
        NULL, status, (__bridge CFStringRef)status_description(status),
        kCFHTTPVersion1_1
    );
    set_header(message, @"Content-Type", contentType);
    set_header(
        message, @"Content-Length",
        [NSString stringWithFormat:@"%llu", contentLength]
    );
    if (closesConnection) set_header(message, @"Connection", @"close");
    return message;
}


static NSData *serialize_and_release(CFHTTPMessageRef message)
{
    NSData *serialized =
        CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    CFRelease(message);
    return serialized;
}


NSData *makeHTTPResponse(
    HTTPStatus status,
    NSString *contentType,
    NSData *body,
    BOOL closesConnection
)
{
    CFHTTPMessageRef message = create_response_message(
        status, contentType, body.length, closesConnection
    );
    CFHTTPMessageSetBody(message, (__bridge CFDataRef)body);
    return serialize_and_release(message);
}


NSData *makeHTTPTextResponse(
    HTTPStatus status, NSString *text, BOOL closesConnection
)
{
    return makeHTTPResponse(
        status, @"text/plain;charset=UTF-8",
        [text dataUsingEncoding:NSUTF8StringEncoding], closesConnection
    );
}


NSData *makeHTTPResponseHeader(
    HTTPStatus status,
    NSString *contentType,
    unsigned long long contentLength,
    BOOL closesConnection
)
{
    return serialize_and_release(create_response_message(
        status, contentType, contentLength, closesConnection
    ));
}


#endif
