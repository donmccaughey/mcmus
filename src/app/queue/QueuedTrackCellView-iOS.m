#import "QueuedTrackCellView-iOS.h"

#if TARGET_OS_IOS
#import "LowerLineWidths.h"

static const CGFloat lineSpacing = 2;
static const CGFloat verticalPadding = 11;

static UILabel *makeLabel(UIFontTextStyle textStyle, UIColor *color)
{
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont preferredFontForTextStyle:textStyle];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

// Whole pixels, so rows and the lines in them land on pixel boundaries.
static CGFloat lineHeight(UIFont *font, UITraitCollection *traitCollection)
{
    CGFloat scale = traitCollection.displayScale;
    return ceil(font.lineHeight * scale) / scale;
}

@implementation QueuedTrackCellView {
    UILabel *_trackLabel;
    UILabel *_albumLabel;
    UILabel *_artistLabel;
}

+ (NSString *)reuseIdentifier
{
    return @"QueuedTrackCell";
}

+ (CGFloat)rowHeightForTraitCollection:(UITraitCollection *)traitCollection
{
    UIFont *trackFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody
                            compatibleWithTraitCollection:traitCollection];
    UIFont *detailFont =
        [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline
            compatibleWithTraitCollection:traitCollection];
    return verticalPadding + lineHeight(trackFont, traitCollection)
        + lineSpacing + lineHeight(detailFont, traitCollection)
        + verticalPadding;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _trackLabel = makeLabel(UIFontTextStyleBody, UIColor.labelColor);
        _albumLabel =
            makeLabel(UIFontTextStyleSubheadline, UIColor.secondaryLabelColor);
        _artistLabel =
            makeLabel(UIFontTextStyleSubheadline, UIColor.secondaryLabelColor);
        _artistLabel.textAlignment = NSTextAlignmentRight;
        for (UILabel *label in @[_trackLabel, _albumLabel, _artistLabel]) {
            [self.contentView addSubview:label];
        }
    }
    return self;
}

- (void)show:(Track *)track
{
    _trackLabel.text = track.trackName;
    _albumLabel.text = track.albumName;
    _artistLabel.text = track.artistName;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect margins = self.contentView.layoutMarginsGuide.layoutFrame;
    CGFloat trackLineHeight =
        lineHeight(_trackLabel.font, self.traitCollection);
    CGFloat detailLineHeight =
        lineHeight(_albumLabel.font, self.traitCollection);
    _trackLabel.frame = CGRectMake(CGRectGetMinX(margins), verticalPadding,
        CGRectGetWidth(margins), trackLineHeight);

    CGFloat lowerY = verticalPadding + trackLineHeight + lineSpacing;
    LowerLineWidths widths = LowerLineWidthsSplit(CGRectGetWidth(margins),
        _albumLabel.intrinsicContentSize.width,
        _artistLabel.intrinsicContentSize.width);
    _albumLabel.frame = CGRectMake(
        CGRectGetMinX(margins), lowerY, widths.album, detailLineHeight);
    _artistLabel.frame = CGRectMake(CGRectGetMaxX(margins) - widths.artist,
        lowerY, widths.artist, detailLineHeight);
}

@end
#endif
