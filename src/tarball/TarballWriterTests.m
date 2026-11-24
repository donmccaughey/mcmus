#import <XCTest/XCTest.h>

#import "FileSystemFake.h"
#import "FileSystemFakeErrorMatching.h"
#import "TarballEntry.h"
#import "TarballWriter.h"
#import "archive.h"
#import "archive_entry.h"


@interface TarballWriterTests : XCTestCase
@end


@interface TarEntry : NSObject

@property (nonatomic) NSData *pathBytes;
@property (nonatomic) unsigned long long size;
@property (nonatomic) time_t mtime;
@property (nonatomic) mode_t permissions;
@property (nonatomic) long long uid;
@property (nonatomic) long long gid;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *groupName;
@property (nonatomic) NSData *contents;

@end


@implementation TarEntry

- (NSString *)path;
{
    return [[NSString alloc] initWithData:_pathBytes
                                 encoding:NSUTF8StringEncoding];
}

@end


static NSString *const baseDirectoryPath = @"/snapshot";


static NSData *utf8(NSString *string)
{
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}


static NSData *patterned_data(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger i = 0; i < length; ++i) {
        bytes[i] = (uint8_t)(i * 31 % 251);
    }
    return data;
}


static NSString *long_path(void)
{
    NSString *album = [@"" stringByPaddingToLength:120
                                        withString:@"Album "
                                   startingAtIndex:0];
    return [NSString stringWithFormat:@"Artist/%@/Track.mp3", album];
}


static NSData *read_entry_data(struct archive *tar, struct archive_entry *entry)
{
    NSMutableData *contents =
        [NSMutableData dataWithLength:(NSUInteger)archive_entry_size(entry)];
    la_ssize_t read =
        archive_read_data(tar, contents.mutableBytes, contents.length);
    XCTAssertEqual(
        read, (la_ssize_t)contents.length, @"%s", archive_error_string(tar)
    );
    return contents;
}


static NSArray<TarEntry *> *read_tar(NSData *data)
{
    NSMutableArray<TarEntry *> *entries = [NSMutableArray array];
    struct archive *tar = archive_read_new();
    XCTAssertEqual(archive_read_support_format_tar(tar), ARCHIVE_OK);
    XCTAssertEqual(
        archive_read_open_memory(tar, data.bytes, data.length), ARCHIVE_OK,
        @"%s", archive_error_string(tar)
    );
    struct archive_entry *header;
    int status;
    while (ARCHIVE_OK == (status = archive_read_next_header(tar, &header))) {
        const char *path = archive_entry_pathname(header);
        TarEntry *entry = [TarEntry new];
        entry.pathBytes = [NSData dataWithBytes:path length:strlen(path)];
        entry.size = (unsigned long long)archive_entry_size(header);
        entry.mtime = archive_entry_mtime(header);
        entry.permissions = archive_entry_perm(header);
        entry.uid = archive_entry_uid(header);
        entry.gid = archive_entry_gid(header);
        entry.userName = @(archive_entry_uname(header) ?: "");
        entry.groupName = @(archive_entry_gname(header) ?: "");
        entry.contents = read_entry_data(tar, header);
        [entries addObject:entry];
    }
    XCTAssertEqual(status, ARCHIVE_EOF, @"%s", archive_error_string(tar));
    XCTAssertEqual(archive_read_free(tar), ARCHIVE_OK);
    return entries;
}


@implementation TarballWriterTests {
    FileSystemFake *_fileSystem;
    NSMutableArray<TarballEntry *> *_entries;
    NSMutableArray<NSData *> *_buffers;
}


- (void)setUp;
{
    [super setUp];
    self.continueAfterFailure = NO;
    _fileSystem = [FileSystemFake new];
    _entries = [NSMutableArray array];
    _buffers = [NSMutableArray array];
}


- (void)addEntry:(NSString *)relativePath
            size:(unsigned long long)size
           mtime:(time_t)mtime;
{
    [_entries addObject:[[TarballEntry alloc] initWithRelativePath:relativePath
                                                              size:size
                                                             mtime:mtime]];
}


- (void)addFile:(NSString *)relativePath contents:(NSData *)contents;
{
    NSString *path =
        [baseDirectoryPath stringByAppendingPathComponent:relativePath];
    [_fileSystem addPath:path contents:contents];
    [self addEntry:relativePath size:contents.length mtime:0];
}


- (TarballWriter *)writer;
{
    return [[TarballWriter alloc]
        initWithBaseDirectory:[NSURL fileURLWithPath:baseDirectoryPath
                                         isDirectory:YES]
                      entries:_entries
                   fileSystem:_fileSystem];
}


- (NSData *)tarFrom:(TarballWriter *)writer;
{
    NSMutableData *tar = [NSMutableData data];
    while (tar.length < writer.tarballSize) {
        NSError *error;
        NSData *buffer = [writer nextBufferAndReturnError:&error];
        XCTAssertNotNil(buffer, @"%@", error);
        [_buffers addObject:buffer];
        [tar appendData:buffer];
    }
    return tar;
}


- (NSError *)failureFrom:(TarballWriter *)writer;
{
    for (int i = 0; i < 1000; ++i) {
        NSError *error;
        if (![writer nextBufferAndReturnError:&error]) return error;
    }
    XCTFail(@"the writer did not fail");
    return nil;
}


#pragma mark - tar contents


- (void)testNoEntriesGivesOnlyTheEndOfArchiveMarker;
{
    TarballWriter *writer = [self writer];

    NSData *tar = [self tarFrom:writer];

    XCTAssertEqualObjects(tar, [NSMutableData dataWithLength:1024]);
    XCTAssertEqual(writer.tarballSize, 1024ULL);
}


- (void)testEntriesAppearInOrderWithRelativePathsAndContents;
{
    [self addFile:@"B Artist/Album/Second.m4a" contents:utf8(@"second")];
    [self addFile:@"A Artist/Album/First.mp3" contents:utf8(@"first")];
    [self addFile:@"Loose.mp3" contents:[NSData data]];

    NSArray<TarEntry *> *read = read_tar([self tarFrom:[self writer]]);

    XCTAssertEqual(read.count, 3UL);
    XCTAssertEqualObjects(read[0].path, @"B Artist/Album/Second.m4a");
    XCTAssertEqualObjects(read[0].contents, utf8(@"second"));
    XCTAssertEqualObjects(read[1].path, @"A Artist/Album/First.mp3");
    XCTAssertEqualObjects(read[1].contents, utf8(@"first"));
    XCTAssertEqualObjects(read[2].path, @"Loose.mp3");
    XCTAssertEqualObjects(read[2].contents, [NSData data]);
}


- (void)testHeaderTakesSizeAndMtimeFromEntry;
{
    [_fileSystem addPath:@"/snapshot/Track.mp3" contents:utf8(@"0123456789")];
    [self addEntry:@"Track.mp3" size:10 mtime:1700000000];

    TarEntry *read = read_tar([self tarFrom:[self writer]])[0];

    XCTAssertEqual(read.size, 10ULL);
    XCTAssertEqual(read.mtime, (time_t)1700000000);
}


- (void)testHeaderHasNoOwnerAndIsReadableAndWritableByEveryone;
{
    [self addFile:@"Track.mp3" contents:utf8(@"data")];

    TarEntry *read = read_tar([self tarFrom:[self writer]])[0];

    XCTAssertEqual(read.permissions, (mode_t)0666);
    XCTAssertEqual(read.uid, 0LL);
    XCTAssertEqual(read.gid, 0LL);
    XCTAssertEqualObjects(read.userName, @"");
    XCTAssertEqualObjects(read.groupName, @"");
}


- (void)testPathLongerThanHeaderNameFieldIsKept;
{
    [self addFile:long_path() contents:utf8(@"data")];

    TarEntry *read = read_tar([self tarFrom:[self writer]])[0];

    XCTAssertEqualObjects(read.path, long_path());
    XCTAssertEqualObjects(read.contents, utf8(@"data"));
}


- (void)testPathBytesKeepTheirNormalForm;
{
    NSString *composed = @"Björk/Track.mp3";
    NSString *decomposed = @"Björk/Track.mp3";
    // A file URL decomposes its path, so both entries locate the same file.
    [_fileSystem addPath:@"/snapshot/Björk/Track.mp3" contents:utf8(@"data")];
    [self addEntry:composed size:4 mtime:0];
    [self addEntry:decomposed size:4 mtime:0];

    NSArray<TarEntry *> *read = read_tar([self tarFrom:[self writer]]);

    XCTAssertEqualObjects(read[0].pathBytes, utf8(composed));
    XCTAssertEqualObjects(read[1].pathBytes, utf8(decomposed));
}


- (void)testFileLargerThanReadBufferKeepsItsContents;
{
    NSData *contents = patterned_data(3 * 1024 * 1024 + 5);
    [self addFile:@"Big.m4a" contents:contents];
    [self addFile:@"Small.mp3" contents:utf8(@"small")];

    NSArray<TarEntry *> *read = read_tar([self tarFrom:[self writer]]);

    XCTAssertTrue([read[0].contents isEqualToData:contents]);
    XCTAssertEqualObjects(read[1].contents, utf8(@"small"));
}


- (void)testFileLongerThanEntrySizeIsCutToEntrySize;
{
    [_fileSystem addPath:@"/snapshot/Track.mp3" contents:utf8(@"0123456789")];
    [self addEntry:@"Track.mp3" size:4 mtime:0];
    [self addFile:@"Next.mp3" contents:utf8(@"next")];

    NSArray<TarEntry *> *read = read_tar([self tarFrom:[self writer]]);

    XCTAssertEqualObjects(read[0].contents, utf8(@"0123"));
    XCTAssertEqualObjects(read[1].contents, utf8(@"next"));
}


#pragma mark - tarball size and buffers


- (void)testTarballSizeIsLengthOfGeneratedTar;
{
    for (NSNumber *size in @[@0, @1, @511, @512, @513, @(70 * 1024)]) {
        NSString *name = [NSString stringWithFormat:@"Size %@.mp3", size];
        [self addFile:name contents:patterned_data(size.unsignedIntegerValue)];
    }
    [self addFile:long_path() contents:utf8(@"long")];
    [self addFile:@"Björk/Track.mp3" contents:utf8(@"decomposed")];
    TarballWriter *writer = [self writer];
    unsigned long long tarballSize = writer.tarballSize;

    NSUInteger length = 0;
    NSData *buffer;
    while ((buffer = [writer nextBufferAndReturnError:NULL])) {
        length += buffer.length;
    }

    XCTAssertEqual(tarballSize, (unsigned long long)length);
    XCTAssertEqual(length % 512, 0UL);
}


- (void)testBuffersAre64KBExceptTheLast;
{
    [self addFile:@"Big.m4a" contents:patterned_data(2 * 1024 * 1024 + 100)];
    [self addFile:@"Small.mp3" contents:utf8(@"small")];

    [self tarFrom:[self writer]];

    XCTAssertGreaterThan(_buffers.count, 32UL);
    for (NSData *buffer in
         [_buffers subarrayWithRange:NSMakeRange(0, _buffers.count - 1)])
    {
        XCTAssertEqual(buffer.length, 64UL * 1024);
    }
    XCTAssertGreaterThan(_buffers.lastObject.length, 0UL);
    XCTAssertLessThanOrEqual(_buffers.lastObject.length, 64UL * 1024);
}


#pragma mark - failures


- (void)testNextBufferAfterCompleteTarFails;
{
    [self addFile:@"Track.mp3" contents:utf8(@"data")];
    TarballWriter *writer = [self writer];
    [self tarFrom:writer];

    NSError *error;
    NSData *buffer = [writer nextBufferAndReturnError:&error];

    XCTAssertNil(buffer);
    XCTAssertEqualObjects(error.domain, TarballErrorDomain);
    XCTAssertEqual(error.code, TarballErrorCodeFinished);
}


- (void)testMissingFileFails;
{
    [self addFile:@"Present.mp3" contents:utf8(@"data")];
    [self addEntry:@"Missing.mp3" size:4 mtime:0];

    NSError *error = [self failureFrom:[self writer]];

    XCTAssertEqualObjects(
        fileSystemFakeErrorPath(error), @"/snapshot/Missing.mp3"
    );
}


- (void)testFailedReadFails;
{
    [self addFile:@"Track.mp3" contents:utf8(@"data")];
    _fileSystem.unreadableAfterOpenFiles =
        [NSSet setWithObject:@"/snapshot/Track.mp3"];

    NSError *error = [self failureFrom:[self writer]];

    XCTAssertEqualObjects(
        fileSystemFakeErrorPath(error), @"/snapshot/Track.mp3"
    );
}


- (void)testFileShorterThanEntrySizeFails;
{
    [_fileSystem addPath:@"/snapshot/Track.mp3" contents:utf8(@"0123")];
    [self addEntry:@"Track.mp3" size:10 mtime:0];

    NSError *error = [self failureFrom:[self writer]];

    XCTAssertEqualObjects(error.domain, TarballErrorDomain);
    XCTAssertEqual(error.code, TarballErrorCodeFileTooShort);
}


- (void)testFailureIsRepeatedByLaterCalls;
{
    [self addEntry:@"Missing.mp3" size:4 mtime:0];
    TarballWriter *writer = [self writer];
    NSError *first = [self failureFrom:writer];

    NSError *second;
    NSData *buffer = [writer nextBufferAndReturnError:&second];

    XCTAssertNil(buffer);
    XCTAssertEqualObjects(second, first);
}


@end
