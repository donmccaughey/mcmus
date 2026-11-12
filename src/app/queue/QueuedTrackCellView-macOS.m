#import "QueuedTrackCellView-macOS.h"

#if TARGET_OS_OSX
#import "LowerLineWidths.h"

static const CGFloat lineSpacing = 2;
static const CGFloat verticalPadding = 4;
static const CGFloat horizontalPadding = 8;

static NSFont *trackFont(void)
{
    return [NSFont preferredFontForTextStyle:NSFontTextStyleBody options:@{}];
}

static NSFont *detailFont(void)
{
    return [NSFont preferredFontForTextStyle:NSFontTextStyleSubheadline
                                     options:@{}];
}

static CGFloat lineHeight(NSFont *font)
{
    return ceil([[[NSLayoutManager alloc] init] defaultLineHeightForFont:font]);
}

static CGFloat trackLineHeight(void)
{
    static CGFloat height = 0;
    if (height == 0) {
        height = lineHeight(trackFont());
    }
    return height;
}

static CGFloat detailLineHeight(void)
{
    static CGFloat height = 0;
    if (height == 0) {
        height = lineHeight(detailFont());
    }
    return height;
}

static NSTextField *makeLabel(NSFont *font, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.maximumNumberOfLines = 1;
    return label;
}

// A truncating label's intrinsicContentSize reports the width it was last
// given, not the width its text wants, so measure the cell directly.
static CGFloat idealWidth(NSTextField *label)
{
    return label.cell.cellSize.width;
}

@implementation QueuedTrackCellView {
    NSTextField *_trackLabel;
    NSTextField *_albumLabel;
    NSTextField *_artistLabel;
}

+ (NSUserInterfaceItemIdentifier)reuseIdentifier
{
    return @"QueuedTrackCell";
}

+ (CGFloat)rowHeight
{
    return verticalPadding + trackLineHeight() + lineSpacing
        + detailLineHeight() + verticalPadding;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.identifier = QueuedTrackCellView.reuseIdentifier;
        _trackLabel = makeLabel(trackFont(), NSColor.labelColor);
        _albumLabel = makeLabel(detailFont(), NSColor.secondaryLabelColor);
        _artistLabel = makeLabel(detailFont(), NSColor.secondaryLabelColor);
        _artistLabel.alignment = NSTextAlignmentRight;
        for (NSTextField *label in @[_trackLabel, _albumLabel, _artistLabel]) {
            [self addSubview:label];
        }
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)show:(Track *)track
{
    _trackLabel.stringValue = track.trackName;
    _albumLabel.stringValue = track.albumName;
    _artistLabel.stringValue = track.artistName;
    self.needsLayout = YES;
}

- (void)layout
{
    [super layout];
    CGFloat x = horizontalPadding;
    CGFloat width = self.bounds.size.width - 2 * horizontalPadding;
    _trackLabel.frame =
        NSMakeRect(x, verticalPadding, width, trackLineHeight());

    CGFloat lowerY = verticalPadding + trackLineHeight() + lineSpacing;
    LowerLineWidths widths = LowerLineWidthsSplit(
        width, idealWidth(_albumLabel), idealWidth(_artistLabel));
    _albumLabel.frame = NSMakeRect(x, lowerY, widths.album, detailLineHeight());
    _artistLabel.frame = NSMakeRect(
        x + width - widths.artist, lowerY, widths.artist, detailLineHeight());
}

@end
#endif
