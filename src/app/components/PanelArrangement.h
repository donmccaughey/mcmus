#import <Foundation/Foundation.h>

typedef NS_CLOSED_ENUM(NSInteger, PanelArrangement) {
    PanelArrangementSideBySide,
    PanelArrangementStacked,
};

PanelArrangement PanelArrangementFitting(CGSize size);
