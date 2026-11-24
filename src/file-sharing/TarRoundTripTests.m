#import <XCTest/XCTest.h>

#import "archive.h"
#import "archive_entry.h"

#import "TarReading.h"

@interface TarRoundTripTests : XCTestCase
@end

static void writeEntry(struct archive *tar, NSString *path, NSData *contents)
{
    struct archive_entry *entry = archive_entry_new();
    archive_entry_copy_pathname(entry, path.UTF8String);
    archive_entry_set_size(entry, (la_int64_t)contents.length);
    archive_entry_set_filetype(entry, AE_IFREG);
    archive_entry_set_perm(entry, 0644);
    XCTAssertEqual(
        archive_write_header(tar, entry), ARCHIVE_OK, @"%s",
        archive_error_string(tar)
    );
    XCTAssertEqual(
        archive_write_data(tar, contents.bytes, contents.length),
        (la_ssize_t)contents.length, @"%s", archive_error_string(tar)
    );
    archive_entry_free(entry);
}

// An app process runs in the "C" locale, where libarchive cannot convert a
// non-ASCII pathname to or from UTF-8. Binary header charset makes the pax
// writer and the tar reader pass pathname bytes through untouched, so
// pathnames are UTF-8 bytes at both ends.
static int setBinaryPaxFormat(struct archive *tar)
{
    int status = archive_write_set_format_pax(tar);
    if (ARCHIVE_OK != status) return status;
    return archive_write_set_options(tar, "hdrcharset=BINARY");
}

static NSData *writeTar(
    NSDictionary<NSString *, NSData *> *files,
    NSArray<NSString *> *order,
    int (*setFormat)(struct archive *)
)
{
    NSMutableData *buffer = [NSMutableData dataWithLength:64 * 1024];
    size_t used = 0;
    struct archive *tar = archive_write_new();
    XCTAssertEqual(setFormat(tar), ARCHIVE_OK);
    XCTAssertEqual(
        archive_write_open_memory(
            tar, buffer.mutableBytes, buffer.length, &used
        ),
        ARCHIVE_OK, @"%s", archive_error_string(tar)
    );
    for (NSString *path in order)
        writeEntry(tar, path, files[path]);
    XCTAssertEqual(archive_write_close(tar), ARCHIVE_OK);
    XCTAssertEqual(archive_write_free(tar), ARCHIVE_OK);
    buffer.length = used;
    return buffer;
}

@implementation TarRoundTripTests {
    NSDictionary<NSString *, NSData *> *_files;
    NSArray<NSString *> *_order;
    NSArray<NSArray *> *_expected;
}

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    NSString *first = @"Artist/Album/First Track.mp3";
    // Longer than the 100 byte ustar name field and not ASCII, so the pax
    // format has to write an extended header for it.
    NSString *second =
        [NSString stringWithFormat:@"Ärtist/%@/Second Track.m4a",
                                   [@"" stringByPaddingToLength:120
                                                     withString:@"Album "
                                                startingAtIndex:0]];
    NSData *firstContents = [@"first" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *secondContents = [NSMutableData dataWithLength:1000];
    _files = @{first: firstContents, second: secondContents};
    _order = @[first, second];
    _expected = @[@[first, firstContents], @[second, secondContents]];
}

- (void)testPaxTarRoundTripsNamesAndContents
{
    NSData *tar = writeTar(_files, _order, setBinaryPaxFormat);

    XCTAssertEqualObjects(readTar(tar), _expected);
}

- (void)testUstarTarRoundTripsShortNameAndContents
{
    NSArray<NSString *> *shortNames = @[_order[0]];

    NSData *tar = writeTar(_files, shortNames, archive_write_set_format_ustar);

    XCTAssertEqualObjects(readTar(tar), @[_expected[0]]);
}

- (void)testTarIsUncompressedAndBlockAligned
{
    NSData *tar = writeTar(_files, _order, setBinaryPaxFormat);

    XCTAssertEqual(tar.length % 512, 0UL);
    NSData *magic = [tar subdataWithRange:NSMakeRange(257, 5)];
    XCTAssertEqualObjects(
        magic, [@"ustar" dataUsingEncoding:NSASCIIStringEncoding]
    );
}

@end
