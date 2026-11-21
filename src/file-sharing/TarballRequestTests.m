#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "HTTPRequestParser.h"
#import "Manifest.h"
#import "TarballEntry.h"
#import "TarballRequest.h"
#import "TrackMetadata.h"


static NSString *const csvContentType = @"text/csv;charset=UTF-8";
static const unsigned long long fiftyMegabytes = 50ULL * 1024 * 1024;


static TrackMetadata *make_metadata(
    NSString *relativePath, unsigned long long size, time_t mtime)
{
    return [[TrackMetadata alloc] initWithRelativePath:relativePath
                                                  size:size
                                                 mtime:mtime
                                              fileHash:1];
}


static HTTPRequest *parse_request(NSString *text)
{
    HTTPRequestParser *parser = [HTTPRequestParser new];
    [parser append:[text dataUsingEncoding:NSUTF8StringEncoding]];
    return parser.request;
}


static HTTPRequest *post_files(NSString *_Nullable contentType, NSString *body)
{
    NSString *contentTypeHeader = contentType
        ? [NSString stringWithFormat:@"Content-Type: %@\r\n", contentType]
        : @"";
    NSUInteger bodyLength =
        [body lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return parse_request([NSString stringWithFormat:@"POST /files HTTP/1.1\r\n"
                                                    @"%@"
                                                    @"Content-Length: %lu\r\n"
                                                    @"\r\n"
                                                    @"%@",
        contentTypeHeader, bodyLength, body]);
}


@interface TarballRequestTests : XCTestCase
@end


@implementation TarballRequestTests {
    Manifest *_manifest;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _manifest = [[Manifest alloc]
        initWithTrackMetadata:@[
            make_metadata(@"Artist/Album/One.mp3", 100, 1700000001),
            make_metadata(@"Artist/Album/Two.m4a", 200, 1700000002),
            make_metadata(@"Piaf, Edith/La Vie en rose (slow chanté).mp3", 300,
                1700000003),
            make_metadata(@"Big/Fifty.mp3", fiftyMegabytes, 0),
            make_metadata(@"Big/Fifty More.mp3", fiftyMegabytes, 0),
            make_metadata(@"Big/One Byte.mp3", 1, 0),
            make_metadata(@"Big/Huge.mp3", 3 * fiftyMegabytes, 0),
        ]
        musicLibraryDirectory:[NSURL fileURLWithPath:@"/snapshot"
                                         isDirectory:YES]];
}


- (NSArray<TarballEntry *> *)entriesForCSV:(NSString *)csv;
{
    NSError *error = nil;
    NSArray<TarballEntry *> *entries =
        parseTarballRequest(post_files(csvContentType, csv), _manifest, &error);
    XCTAssertNotNil(entries, @"%@", error);
    return entries;
}


- (void)assertRequest:(HTTPRequest *)request
        failsWithCode:(TarballRequestErrorCode)code
          description:(NSString *)description;
{
    NSError *error = nil;
    XCTAssertNil(parseTarballRequest(request, _manifest, &error));
    XCTAssertEqualObjects(error.domain, TarballRequestErrorDomain);
    XCTAssertEqual(error.code, code);
    XCTAssertEqualObjects(error.localizedDescription, description);
}


- (void)assertCSV:(NSString *)csv
    failsWithCode:(TarballRequestErrorCode)code
      description:(NSString *)description;
{
    [self assertRequest:post_files(csvContentType, csv)
          failsWithCode:code
            description:description];
}


#pragma mark - valid requests


- (void)testEntriesAreInTheOrderOfTheCSV;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\r\n"
                            @"Artist/Album/Two.m4a\r\n"
                            @"Artist/Album/One.mp3\r\n"];

    XCTAssertEqualObjects([entries valueForKey:@"relativePath"],
        (@[@"Artist/Album/Two.m4a", @"Artist/Album/One.mp3"]));
}


- (void)testEntriesTakeSizeAndMtimeFromTheManifest;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\r\nArtist/Album/Two.m4a\r\n"];

    XCTAssertEqual(entries.count, 1UL);
    XCTAssertEqual(entries[0].size, 200ULL);
    XCTAssertEqual(entries[0].mtime, 1700000002);
}


- (void)testAcceptsQuotedPathsWithCommasAndNonASCIICharacters;
{
    NSArray<TarballEntry *> *entries = [self
        entriesForCSV:@"path\r\n"
                      @"\"Piaf, Edith/La Vie en rose (slow chanté).mp3\"\r\n"];

    XCTAssertEqualObjects(entries[0].relativePath,
        @"Piaf, Edith/La Vie en rose (slow chanté).mp3");
    XCTAssertEqual(entries[0].size, 300ULL);
}


- (void)testAcceptsCSVWithoutAFinalRecordEnding;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\nArtist/Album/One.mp3"];

    XCTAssertEqual(entries.count, 1UL);
}


- (void)testARepeatedPathGetsAnEntryEachTime;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\r\n"
                            @"Artist/Album/One.mp3\r\n"
                            @"Artist/Album/One.mp3\r\n"];

    XCTAssertEqual(entries.count, 2UL);
}


#pragma mark - content length and content type


- (void)testMissingContentLengthIsInvalidContentLength;
{
    HTTPRequest *request = parse_request(@"POST /files HTTP/1.1\r\n"
                                         @"Content-Type: text/csv;charset=UTF-8"
                                         @"\r\n\r\n");

    [self assertRequest:request
          failsWithCode:TarballRequestErrorCodeInvalidContentLength
            description:@"Invalid content length"];
}


- (void)testZeroContentLengthIsInvalidContentLength;
{
    [self assertCSV:@""
        failsWithCode:TarballRequestErrorCodeInvalidContentLength
          description:@"Invalid content length"];
}


- (void)testContentLengthIsCheckedBeforeContentType;
{
    [self assertRequest:post_files(@"text/plain", @"")
          failsWithCode:TarballRequestErrorCodeInvalidContentLength
            description:@"Invalid content length"];
}


- (void)testMissingContentTypeIsInvalidContentType;
{
    [self assertRequest:post_files(nil, @"path\r\nArtist/Album/One.mp3\r\n")
          failsWithCode:TarballRequestErrorCodeInvalidContentType
            description:@"Invalid content type"];
}


- (void)testOtherContentTypesAreInvalidContentType;
{
    NSString *csv = @"path\r\nArtist/Album/One.mp3\r\n";
    for (NSString *contentType in @[
             @"text/plain",
             @"text/csv",
             @"text/csv;charset=ISO-8859-1",
             @"text/csv; charset=UTF-8",
             @"text/csv;charset=utf-8",
         ]) {
        [self assertRequest:post_files(contentType, csv)
              failsWithCode:TarballRequestErrorCodeInvalidContentType
                description:@"Invalid content type"];
    }
}


- (void)testContentTypeIsCheckedBeforeTheCSV;
{
    [self assertRequest:post_files(@"text/plain", @"\"unterminated")
          failsWithCode:TarballRequestErrorCodeInvalidContentType
            description:@"Invalid content type"];
}


#pragma mark - CSV


- (void)testCSVThatCannotBeParsedIsInvalidCSV;
{
    [self assertCSV:@"path\r\n\"Artist/Album/One.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeInvalidCSV
          description:@"Invalid CSV"];
}


- (void)testCSVWithOnlyTheHeaderIsInvalidCSV;
{
    for (NSString *csv in @[@"path", @"path\r\n"]) {
        [self assertCSV:csv
            failsWithCode:TarballRequestErrorCodeInvalidCSV
              description:@"Invalid CSV"];
    }
}


- (void)testCSVWithoutThePathHeaderIsInvalidCSV;
{
    for (NSString *csv in @[
             @"Artist/Album/One.mp3\r\nArtist/Album/Two.m4a\r\n",
             @"Path\r\nArtist/Album/One.mp3\r\n",
             @"path,size\r\nArtist/Album/One.mp3,100\r\n",
         ]) {
        [self assertCSV:csv
            failsWithCode:TarballRequestErrorCodeInvalidCSV
              description:@"Invalid CSV"];
    }
}


- (void)testCSVWithInconsistentFieldCountsIsInvalidCSV;
{
    [self assertCSV:@"path\r\nArtist/Album/One.mp3,100\r\n"
        failsWithCode:TarballRequestErrorCodeInvalidCSV
          description:@"Invalid CSV"];
}


#pragma mark - tracks


- (void)testPathNotInTheManifestIsUnknownTrack;
{
    [self assertCSV:@"path\r\n"
                    @"Artist/Album/One.mp3\r\n"
                    @"Artist/Album/Three.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeUnknownTrack
          description:@"Unknown track"];
}


- (void)testAbsolutePathIsUnknownTrack;
{
    [self assertCSV:@"path\r\n/snapshot/Artist/Album/One.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeUnknownTrack
          description:@"Unknown track"];
}


- (void)testBlankLineIsUnknownTrack;
{
    [self assertCSV:@"path\r\nArtist/Album/One.mp3\r\n\r\n"
        failsWithCode:TarballRequestErrorCodeUnknownTrack
          description:@"Unknown track"];
}


- (void)testUnknownTrackIsCheckedBeforeTheRequestedSize;
{
    [self assertCSV:@"path\r\n"
                    @"Big/Huge.mp3\r\n"
                    @"Big/Fifty.mp3\r\n"
                    @"Artist/Album/Three.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeUnknownTrack
          description:@"Unknown track"];
}


#pragma mark - requested size


- (void)testTracksOfExactlyOneHundredMegabytesAreAccepted;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\r\n"
                            @"Big/Fifty.mp3\r\n"
                            @"Big/Fifty More.mp3\r\n"];

    XCTAssertEqual(entries.count, 2UL);
}


- (void)testTracksOfMoreThanOneHundredMegabytesAreTooBig;
{
    [self assertCSV:@"path\r\n"
                    @"Big/Fifty.mp3\r\n"
                    @"Big/Fifty More.mp3\r\n"
                    @"Big/One Byte.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeTarballTooBig
          description:@"Tarball too big"];
}


- (void)testOneTrackOfMoreThanOneHundredMegabytesIsAccepted;
{
    NSArray<TarballEntry *> *entries =
        [self entriesForCSV:@"path\r\nBig/Huge.mp3\r\n"];

    XCTAssertEqual(entries.count, 1UL);
    XCTAssertEqual(entries[0].size, 3 * fiftyMegabytes);
}


- (void)testARepeatedTrackCountsEachTimeTowardTheRequestedSize;
{
    [self assertCSV:@"path\r\nBig/Huge.mp3\r\nBig/Huge.mp3\r\n"
        failsWithCode:TarballRequestErrorCodeTarballTooBig
          description:@"Tarball too big"];
}


@end


#endif
