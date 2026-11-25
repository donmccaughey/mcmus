#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <XCTest/XCTest.h>

#import "FileShareSelection.h"


static const NSUInteger fileShareCount = 3;


@interface FileShareSelectionTests : XCTestCase
@end


@implementation FileShareSelectionTests


- (void)assertInput:(nullable NSString *)input selectsIndex:(NSUInteger)index;
{
    FileShareSelection selection =
        parse_file_share_selection(input, fileShareCount);
    XCTAssertEqual(
        selection.kind, FileShareSelectionKindSelected, @"%@", input
    );
    XCTAssertEqual(selection.index, index, @"%@", input);
}


- (void)assertInput:(nullable NSString *)input
            hasKind:(FileShareSelectionKind)kind;
{
    FileShareSelection selection =
        parse_file_share_selection(input, fileShareCount);
    XCTAssertEqual(selection.kind, kind, @"%@", input);
}


- (void)testNumbersInRangeSelectZeroBasedIndex;
{
    [self assertInput:@"1" selectsIndex:0];
    [self assertInput:@"2" selectsIndex:1];
    [self assertInput:@"3" selectsIndex:2];
}


- (void)testSurroundingWhitespaceIsIgnored;
{
    [self assertInput:@" 2 \n" selectsIndex:1];
    [self assertInput:@"\t3\n" selectsIndex:2];
}


- (void)testLeadingZerosAreIgnored;
{
    [self assertInput:@"02" selectsIndex:1];
}


- (void)testNumbersOutOfRangeAreInvalid;
{
    [self assertInput:@"0" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"4" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"99999999999999999999999999"
              hasKind:FileShareSelectionKindInvalid];
}


- (void)testNonNumbersAreInvalid;
{
    [self assertInput:@"" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"\n" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"abc" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"2x" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"-1" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"+1" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"1 2" hasKind:FileShareSelectionKindInvalid];
    [self assertInput:@"qq" hasKind:FileShareSelectionKindInvalid];
}


- (void)testQCancels;
{
    [self assertInput:@"q" hasKind:FileShareSelectionKindCancelled];
    [self assertInput:@"Q" hasKind:FileShareSelectionKindCancelled];
    [self assertInput:@" q\n" hasKind:FileShareSelectionKindCancelled];
}


- (void)testEndOfInputCancels;
{
    [self assertInput:nil hasKind:FileShareSelectionKindCancelled];
}


@end


#endif
