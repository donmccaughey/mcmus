#import "PanelArrangement.h"

PanelArrangement PanelArrangementFitting(CGSize size)
{
    return size.width > size.height ? PanelArrangementSideBySide
                                    : PanelArrangementStacked;
}
