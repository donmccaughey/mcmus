#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "HTTPResponse.h"


static NSString *text(NSData *response)
{
    return [[NSString alloc] initWithData:response
                                 encoding:NSUTF8StringEncoding];
}


// CFHTTPMessage serializes header fields in no particular order, so the
// tests compare them as a set.
static NSArray<NSString *> *head_lines(NSData *response)
{
    NSString *head =
        [text(response) componentsSeparatedByString:@"\r\n\r\n"].firstObject;
    return [head componentsSeparatedByString:@"\r\n"];
}


static NSString *status_line(NSData *response)
{
    return head_lines(response).firstObject;
}


static NSSet<NSString *> *headers(NSData *response)
{
    NSArray<NSString *> *lines = head_lines(response);
    NSRange afterStatusLine = NSMakeRange(1, lines.count - 1);
    return [NSSet setWithArray:[lines subarrayWithRange:afterStatusLine]];
}


static NSString *body_text(NSData *response)
{
    NSString *all = text(response);
    NSRange blankLine = [all rangeOfString:@"\r\n\r\n"];
    return [all substringFromIndex:NSMaxRange(blankLine)];
}


@interface HTTPResponseTests : XCTestCase
@end


@implementation HTTPResponseTests


- (void)testResponseHasStatusLineHeadersAndBody;
{
    NSData *body =
        [@"path,size,hash\r\n" dataUsingEncoding:NSUTF8StringEncoding];

    NSData *response =
        makeHTTPResponse(HTTPStatusOK, @"text/csv;charset=UTF-8", body, NO);

    XCTAssertEqualObjects(status_line(response), @"HTTP/1.1 200 OK");
    XCTAssertEqualObjects(headers(response), ([NSSet setWithArray:@[
        @"Content-Type: text/csv;charset=UTF-8",
        @"Content-Length: 16",
    ]]));
    XCTAssertEqualObjects(body_text(response), @"path,size,hash\r\n");
}


- (void)testClosingResponseHasConnectionCloseHeader;
{
    NSData *response =
        makeHTTPTextResponse(HTTPStatusBadRequest, @"Invalid request", YES);

    XCTAssertEqualObjects(status_line(response), @"HTTP/1.1 400 Bad Request");
    XCTAssertEqualObjects(headers(response), ([NSSet setWithArray:@[
        @"Content-Type: text/plain;charset=UTF-8",
        @"Content-Length: 15",
        @"Connection: close",
    ]]));
    XCTAssertEqualObjects(body_text(response), @"Invalid request");
}


- (void)testContentLengthCountsUTF8Bytes;
{
    NSData *response = makeHTTPTextResponse(HTTPStatusNotFound, @"é", NO);

    XCTAssertTrue([text(response) containsString:@"Content-Length: 2\r\n"]);
}


- (void)testResponseHeaderEndsAfterTheBlankLine;
{
    NSData *header = makeHTTPResponseHeader(
        HTTPStatusOK, @"application/x-tar", 5000000000ULL, NO);

    XCTAssertEqualObjects(status_line(header), @"HTTP/1.1 200 OK");
    XCTAssertEqualObjects(headers(header), ([NSSet setWithArray:@[
        @"Content-Type: application/x-tar",
        @"Content-Length: 5000000000",
    ]]));
    XCTAssertTrue([text(header) hasSuffix:@"\r\n\r\n"], @"%@", text(header));
    XCTAssertEqualObjects(body_text(header), @"");
}


- (void)testClosingResponseHeaderHasConnectionCloseHeader;
{
    NSData *header =
        makeHTTPResponseHeader(HTTPStatusOK, @"application/x-tar", 1024, YES);

    XCTAssertEqualObjects(headers(header), ([NSSet setWithArray:@[
        @"Content-Type: application/x-tar",
        @"Content-Length: 1024",
        @"Connection: close",
    ]]));
}


- (void)testStatusLines;
{
    NSDictionary<NSNumber *, NSString *> *statusLines = @{
        @(HTTPStatusOK): @"HTTP/1.1 200 OK\r\n",
        @(HTTPStatusBadRequest): @"HTTP/1.1 400 Bad Request\r\n",
        @(HTTPStatusNotFound): @"HTTP/1.1 404 Not Found\r\n",
        @(HTTPStatusMethodNotAllowed): @"HTTP/1.1 405 Method Not Allowed\r\n",
        @(HTTPStatusTooManyRequests): @"HTTP/1.1 429 Too Many Requests\r\n",
        @(HTTPStatusInternalServerError):
            @"HTTP/1.1 500 Internal Server Error\r\n",
        @(HTTPStatusServiceUnavailable):
            @"HTTP/1.1 503 Service Unavailable\r\n",
    };

    for (NSNumber *status in statusLines) {
        NSData *response = makeHTTPTextResponse(status.integerValue, @"", NO);

        XCTAssertTrue([text(response) hasPrefix:statusLines[status]], @"%@",
            text(response));
    }
}


@end


#endif
