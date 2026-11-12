#import <XCTest/XCTest.h>

#import "LowerLineWidths.h"

@interface LowerLineWidthsTests : XCTestCase
@end

@implementation LowerLineWidthsTests

- (void)testBothFitSoEachTakesItsIdealWidth
{
    LowerLineWidths widths = LowerLineWidthsSplit(300, 100, 80);
    XCTAssertEqual(widths.album, 100.0);
    XCTAssertEqual(widths.artist, 192.0);
}

- (void)testBothTooLongSplitsSixtyForty
{
    LowerLineWidths widths = LowerLineWidthsSplit(300, 500, 500);
    XCTAssertEqual(widths.album, 172.0);
    XCTAssertEqual(widths.artist, 120.0);
}

- (void)testAlbumCapIsRoundedDown
{
    LowerLineWidths widths = LowerLineWidthsSplit(301, 500, 500);
    XCTAssertEqual(widths.album, 172.0);
    XCTAssertEqual(widths.artist, 121.0);
}

- (void)testLongAlbumTakesWhatTheArtistLeaves
{
    LowerLineWidths widths = LowerLineWidthsSplit(300, 500, 50);
    XCTAssertEqual(widths.album, 242.0);
    XCTAssertEqual(widths.artist, 50.0);
}

- (void)testLongArtistTakesWhatTheAlbumLeaves
{
    LowerLineWidths widths = LowerLineWidthsSplit(300, 50, 500);
    XCTAssertEqual(widths.album, 50.0);
    XCTAssertEqual(widths.artist, 242.0);
}

- (void)testAlbumNeverGoesNegative
{
    LowerLineWidths widths = LowerLineWidthsSplit(10, 500, 500);
    XCTAssertEqual(widths.album, 0.0);
    XCTAssertEqual(widths.artist, 4.0);
}

@end
