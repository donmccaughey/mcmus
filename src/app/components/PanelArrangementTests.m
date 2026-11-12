#import <XCTest/XCTest.h>

#import "PanelArrangement.h"

@interface PanelArrangementTests : XCTestCase
@end

@implementation PanelArrangementTests

- (void)testWiderThanTallIsSideBySide
{
    XCTAssertEqual(PanelArrangementFitting(CGSizeMake(844, 390)),
        PanelArrangementSideBySide);
}

- (void)testTallerThanWideIsStacked
{
    XCTAssertEqual(
        PanelArrangementFitting(CGSizeMake(390, 844)), PanelArrangementStacked);
}

- (void)testSquareIsStacked
{
    XCTAssertEqual(
        PanelArrangementFitting(CGSizeMake(500, 500)), PanelArrangementStacked);
}

@end
