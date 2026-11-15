#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "HTTPRequestParser.h"


static NSData *utf8(NSString *text)
{
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}


@interface HTTPRequestParserTests : XCTestCase
@end


@implementation HTTPRequestParserTests {
    HTTPRequestParser *_parser;
}


- (void)setUp;
{
    [super setUp];
    _parser = [HTTPRequestParser new];
}


- (void)append:(NSString *)text;
{
    [_parser append:utf8(text)];
}


- (void)testNewParserIsIncomplete;
{
    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);
    XCTAssertNil(_parser.request);
}


- (void)testParsesGetRequest;
{
    [self append:@"GET /manifest HTTP/1.1\r\n"
                 @"Host: mac.local:50000\r\n"
                 @"User-Agent: Don's iPhone\r\n"
                 @"\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertEqualObjects(_parser.request.method, @"GET");
    XCTAssertEqualObjects(_parser.request.path, @"/manifest");
    XCTAssertEqualObjects(_parser.request.userAgent, @"Don's iPhone");
    XCTAssertEqualObjects(_parser.request.body, [NSData data]);
    XCTAssertFalse(_parser.request.closesConnection);
    XCTAssertEqualObjects(_parser.excessData, [NSData data]);
}


- (void)testParsesRequestWithoutHostHeader;
{
    [self append:@"GET /manifest HTTP/1.1\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertEqualObjects(_parser.request.path, @"/manifest");
}


- (void)testRequestSplitAcrossAppendsIsIncompleteUntilTheBlankLine;
{
    [self append:@"GET /mani"];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);

    [self append:@"fest HTTP/1.1\r\nUser-Agent: iPad\r\n"];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);

    [self append:@"\r\n"];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertEqualObjects(_parser.request.path, @"/manifest");
    XCTAssertEqualObjects(_parser.request.userAgent, @"iPad");
}


- (void)testPathOmitsQuery;
{
    [self append:@"GET /manifest?fresh=1 HTTP/1.1\r\n\r\n"];

    XCTAssertEqualObjects(_parser.request.path, @"/manifest");
}


- (void)testMissingUserAgentIsNil;
{
    [self append:@"GET /manifest HTTP/1.1\r\nHost: mac.local\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertNil(_parser.request.userAgent);
}


- (void)testEmptyUserAgentIsNil;
{
    [self append:@"GET /manifest HTTP/1.1\r\nUser-Agent:\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertNil(_parser.request.userAgent);
}


- (void)testHeaderNamesAreCaseInsensitive;
{
    [self append:@"GET /manifest HTTP/1.1\r\nuser-agent: iPad\r\n\r\n"];

    XCTAssertEqualObjects(_parser.request.userAgent, @"iPad");
}


- (void)testConnectionCloseHeaderClosesConnection;
{
    [self append:@"GET /manifest HTTP/1.1\r\nConnection: Close\r\n\r\n"];

    XCTAssertTrue(_parser.request.closesConnection);
}


- (void)testHTTP10ClosesConnection;
{
    [self append:@"GET /manifest HTTP/1.0\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertTrue(_parser.request.closesConnection);
}


- (void)testBodyIsReadToContentLength;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: 11\r\n\r\npath\r"];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);

    [self append:@"\na.mp3"];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertEqualObjects(_parser.request.method, @"POST");
    XCTAssertEqualObjects(_parser.request.body, utf8(@"path\r\na.mp3"));
    XCTAssertEqualObjects(_parser.excessData, [NSData data]);
}


- (void)testBytesAfterRequestAreExcessData;
{
    [self append:@"GET /manifest HTTP/1.1\r\n\r\nGET /next"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateComplete);
    XCTAssertEqualObjects(_parser.excessData, utf8(@"GET /next"));
}


- (void)testBytesAfterBodyAreExcessData;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: 4\r\n\r\npathGET"];

    XCTAssertEqualObjects(_parser.request.body, utf8(@"path"));
    XCTAssertEqualObjects(_parser.excessData, utf8(@"GET"));
}


- (void)testAppendAfterCompleteIsIgnored;
{
    [self append:@"GET /manifest HTTP/1.1\r\n\r\n"];

    [self append:@"GET /other HTTP/1.1\r\n\r\n"];

    XCTAssertEqualObjects(_parser.request.path, @"/manifest");
    XCTAssertEqualObjects(_parser.excessData, [NSData data]);
}


#pragma mark - invalid requests


- (void)testTextThatIsNotHTTPIsInvalid;
{
    [self append:@"hello there\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
    XCTAssertNil(_parser.request);
}


- (void)testBinaryDataIsInvalid;
{
    uint8_t bytes[] = {0x16, 0x03, 0x01, 0x02, 0x00, 0x01, 0x00, 0x01, 0xfc,
        0x03, 0x03, '\r', '\n', '\r', '\n'};

    [_parser append:[NSData dataWithBytes:bytes length:sizeof bytes]];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testUnsupportedHTTPVersionIsInvalid;
{
    [self append:@"GET /manifest HTTP/2.0\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testNonNumericContentLengthIsInvalid;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: ten\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testNegativeContentLengthIsInvalid;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: -1\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testBodyLongerThanOneMegabyteIsInvalid;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: 1048577\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testBodyOfOneMegabyteIsAccepted;
{
    [self append:@"POST /files HTTP/1.1\r\nContent-Length: 1048576\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);
}


- (void)testChunkedBodyIsInvalid;
{
    [self append:@"POST /files HTTP/1.1\r\n"
                 @"Transfer-Encoding: chunked\r\n"
                 @"\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testUnfinishedHeaderLongerThanSixteenKilobytesIsInvalid;
{
    [self append:@"GET /manifest HTTP/1.1\r\nX-Padding: "];
    XCTAssertEqual(_parser.state, HTTPRequestParserStateIncomplete);

    [self append:[@"" stringByPaddingToLength:16 * 1024
                                   withString:@"x"
                              startingAtIndex:0]];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testFinishedHeaderLongerThanSixteenKilobytesIsInvalid;
{
    NSString *padding = [@"" stringByPaddingToLength:16 * 1024
                                          withString:@"x"
                                     startingAtIndex:0];

    [self append:[NSString stringWithFormat:@"GET /manifest HTTP/1.1\r\n"
                                            @"X-Padding: %@\r\n\r\n",
                     padding]];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


- (void)testInvalidParserStaysInvalid;
{
    [self append:@"hello there\r\n\r\n"];

    [self append:@"GET /manifest HTTP/1.1\r\n\r\n"];

    XCTAssertEqual(_parser.state, HTTPRequestParserStateInvalid);
}


@end


#endif
