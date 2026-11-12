#import "LowerLineWidths.h"

static const CGFloat albumMaxFraction = 0.6;
static const CGFloat albumTrailingPadding = 8;

LowerLineWidths LowerLineWidthsSplit(
    CGFloat available, CGFloat albumIdeal, CGFloat artistIdeal)
{
    CGFloat albumCap = floor(available * albumMaxFraction);
    CGFloat albumSlotAvailable = MAX(albumCap, available - artistIdeal);
    CGFloat albumSlot =
        MIN(albumIdeal + albumTrailingPadding, albumSlotAvailable);
    return (LowerLineWidths){
        .album = MAX(0, albumSlot - albumTrailingPadding),
        .artist = available - albumSlot,
    };
}
