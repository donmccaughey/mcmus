#import <XCTest/XCTest.h>

#import "ClockFake.h"
#import "DNSFake.h"
#import "FileSyncing.h"
#import "FileSyncingDelegate.h"
#import "FileSystemFake.h"
#import "Manifest.h"


@interface FileSyncingDelegateStub : NSObject <FileSyncingDelegate>
@end


@implementation FileSyncingDelegateStub


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    willSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFindFileShares:(NSArray<FileShare *> *)fileShares;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToFindFileSharesWithError:(NSError *)error;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                  toURL:(NSURL *)url;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToResolveFileShare:(FileShare *)fileShare
                    withError:(NSError *)error;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
     didGetManifest:(Manifest *)manifest;
{
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToGetManifestWithError:(NSError *)error;
{
}


@end


static NSURL *manifest_path(void)
{
    return [NSURL fileURLWithPath:@"/Working/manifest.csv"];
}


static FileSystemFake *file_system_with_manifest(NSString *csv)
{
    FileSystemFake *fileSystem = [FileSystemFake new];
    [fileSystem addPath:manifest_path().path
               contents:[csv dataUsingEncoding:NSUTF8StringEncoding]];
    return fileSystem;
}


@interface FileSyncingTests : XCTestCase
@end


@implementation FileSyncingTests {
    dispatch_queue_t _serialQueue;
    FileSyncingDelegateStub *_delegate;
}


- (void)setUp;
{
    _serialQueue = dispatch_queue_create(
        NSStringFromClass(self.class).UTF8String, DISPATCH_QUEUE_SERIAL
    );
    _delegate = [FileSyncingDelegateStub new];
}


- (FileSyncing *)fileSyncingWithFileSystem:(FileSystemFake *)fileSystem;
{
    return [[FileSyncing alloc]
        initWithMusicDir:[NSURL fileURLWithPath:@"/Music" isDirectory:YES]
              workingDir:[NSURL fileURLWithPath:@"/Working" isDirectory:YES]
            manifestPath:manifest_path()
             serialQueue:_serialQueue
                delegate:_delegate
           delegateQueue:dispatch_get_main_queue()
              fileSystem:fileSystem
                     dns:[DNSFake new]
                   clock:[ClockFake new]];
}


- (void)testLocalManifestIsReadFromTheManifestPath;
{
    FileSystemFake *fileSystem = file_system_with_manifest(
        @"path,size,hash\r\nArtist/Album/Song.mp3,5,7\r\nTune.m4a,9,11\r\n"
    );

    FileSyncing *fileSyncing = [self fileSyncingWithFileSystem:fileSystem];

    XCTAssertEqual(fileSyncing.localManifest.trackCount, 2UL);
    XCTAssertNotNil([fileSyncing.localManifest
        metadataForRelativePath:@"Tune.m4a"]);
}


- (void)testLocalManifestIsEmptyWhenTheManifestFileIsMissing;
{
    FileSyncing *fileSyncing =
        [self fileSyncingWithFileSystem:[FileSystemFake new]];

    XCTAssertNotNil(fileSyncing.localManifest);
    XCTAssertEqual(fileSyncing.localManifest.trackCount, 0UL);
}


- (void)testLocalManifestIsEmptyWhenTheManifestFileIsMalformed;
{
    FileSystemFake *fileSystem =
        file_system_with_manifest(@"name,bytes\r\nTune.m4a,9\r\n");

    FileSyncing *fileSyncing = [self fileSyncingWithFileSystem:fileSystem];

    XCTAssertNotNil(fileSyncing.localManifest);
    XCTAssertEqual(fileSyncing.localManifest.trackCount, 0UL);
}


- (void)testServerManifestIsNilBeforeGettingTheManifest;
{
    FileSyncing *fileSyncing =
        [self fileSyncingWithFileSystem:[FileSystemFake new]];

    XCTAssertNil(fileSyncing.serverManifest);
}


@end
