#import <XCTest/XCTest.h>

#import "FileShare.h"


static FileShare *file_share(
    uint32_t interfaceIndex,
    char const *serviceName,
    char const *regtype,
    char const *replyDomain
)
{
    return [[FileShare alloc] initWithInterfaceIndex:interfaceIndex
                                         serviceName:serviceName
                                             regtype:regtype
                                         replyDomain:replyDomain];
}


static FileShare *file_share_on_interface(uint32_t interfaceIndex)
{
    return file_share(interfaceIndex, "Den Mac", "_mcmus._tcp.", "local.");
}


@interface FileShareTests : XCTestCase
@end


@implementation FileShareTests


#pragma mark - initWithInterfaceIndex:serviceName:regtype:replyDomain: tests


- (void)testInitKeepsEveryProperty;
{
    FileShare *fileShare = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");

    XCTAssertEqual(fileShare.interfaceIndex, 4UL);
    XCTAssertEqualObjects(fileShare.serviceName, @"Den Mac");
    XCTAssertEqualObjects(fileShare.serviceType, @"_mcmus._tcp.");
    XCTAssertEqualObjects(fileShare.domain, @"local.");
}


- (void)testInitDecodesUTF8ServiceName;
{
    FileShare *fileShare =
        file_share(4, "Don\xE2\x80\x99s Mac", "_mcmus._tcp.", "local.");

    XCTAssertEqualObjects(fileShare.serviceName, @"Don’s Mac");
}


- (void)testInitKeepsLargestInterfaceIndex;
{
    FileShare *fileShare = file_share_on_interface(UINT32_MAX);

    XCTAssertEqual(fileShare.interfaceIndex, (NSUInteger)UINT32_MAX);
}


#pragma mark - isSameFileShare: tests


- (void)testSameFileShareOnAnotherInterface;
{
    FileShare *wifi = file_share_on_interface(4);
    FileShare *ethernet = file_share_on_interface(7);

    XCTAssertTrue([wifi isSameFileShare:ethernet]);
    XCTAssertTrue([ethernet isSameFileShare:wifi]);
}


- (void)testDifferentServiceNameIsNotSameFileShare;
{
    FileShare *den = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *office = file_share(4, "Office Mac", "_mcmus._tcp.", "local.");

    XCTAssertFalse([den isSameFileShare:office]);
}


- (void)testDifferentServiceTypeIsNotSameFileShare;
{
    FileShare *mcmus = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *http = file_share(4, "Den Mac", "_http._tcp.", "local.");

    XCTAssertFalse([mcmus isSameFileShare:http]);
}


- (void)testDifferentDomainIsNotSameFileShare;
{
    FileShare *local = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *wide = file_share(4, "Den Mac", "_mcmus._tcp.", "example.com.");

    XCTAssertFalse([local isSameFileShare:wide]);
}


#pragma mark - isEqual: and hash tests


- (void)testFileSharesWithSameValuesAreEqual;
{
    FileShare *first = file_share_on_interface(4);
    FileShare *second = file_share_on_interface(4);

    XCTAssertEqualObjects(first, second);
    XCTAssertEqual(first.hash, second.hash);
}


- (void)testFileShareIsEqualToItself;
{
    FileShare *fileShare = file_share_on_interface(4);

    XCTAssertEqualObjects(fileShare, fileShare);
}


- (void)testFileSharesOnDifferentInterfacesAreNotEqual;
{
    FileShare *wifi = file_share_on_interface(4);
    FileShare *ethernet = file_share_on_interface(7);

    XCTAssertNotEqualObjects(wifi, ethernet);
}


- (void)testFileSharesWithDifferentServiceNameAreNotEqual;
{
    FileShare *den = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *office = file_share(4, "Office Mac", "_mcmus._tcp.", "local.");

    XCTAssertNotEqualObjects(den, office);
}


- (void)testFileSharesWithDifferentServiceTypeAreNotEqual;
{
    FileShare *mcmus = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *http = file_share(4, "Den Mac", "_http._tcp.", "local.");

    XCTAssertNotEqualObjects(mcmus, http);
}


- (void)testFileSharesWithDifferentDomainAreNotEqual;
{
    FileShare *local = file_share(4, "Den Mac", "_mcmus._tcp.", "local.");
    FileShare *wide = file_share(4, "Den Mac", "_mcmus._tcp.", "example.com.");

    XCTAssertNotEqualObjects(local, wide);
}


- (void)testFileShareIsNotEqualToOtherKindsOfObject;
{
    XCTAssertNotEqualObjects(file_share_on_interface(4), @"Den Mac");
}


- (void)testSetHoldsOneFileSharePerInterface;
{
    NSSet<FileShare *> *fileShares = [NSSet setWithArray:@[
        file_share_on_interface(4),
        file_share_on_interface(4),
        file_share_on_interface(7),
    ]];

    XCTAssertEqual(fileShares.count, 2UL);
}


// Browser drops a share that goes away by removing a newly built equal one.
- (void)testArrayRemovesEqualFileShare;
{
    NSMutableArray<FileShare *> *fileShares = [NSMutableArray new];
    [fileShares addObject:file_share_on_interface(4)];
    [fileShares addObject:file_share_on_interface(7)];

    [fileShares removeObject:file_share_on_interface(4)];

    XCTAssertEqualObjects(fileShares, (@[file_share_on_interface(7)]));
}


@end
