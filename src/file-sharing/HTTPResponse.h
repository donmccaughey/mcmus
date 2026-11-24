#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, HTTPStatus) {
    HTTPStatusOK = 200,
    HTTPStatusBadRequest = 400,
    HTTPStatusNotFound = 404,
    HTTPStatusMethodNotAllowed = 405,
    HTTPStatusTooManyRequests = 429,
    HTTPStatusInternalServerError = 500,
    HTTPStatusServiceUnavailable = 503,
};


// Both return a complete serialized HTTP 1.1 response.
NSData *makeHTTPResponse(HTTPStatus status,
    NSString *contentType,
    NSData *body,
    BOOL closesConnection);
NSData *makeHTTPTextResponse(
    HTTPStatus status, NSString *text, BOOL closesConnection);

// The status line and header fields of a response whose body is sent
// separately.
NSData *makeHTTPResponseHeader(HTTPStatus status,
    NSString *contentType,
    unsigned long long contentLength,
    BOOL closesConnection);


NS_ASSUME_NONNULL_END


#endif
