#import "ShareStatusBarView.h"

#if TARGET_OS_OSX
static const CGFloat leadingPadding = 16;
// Lines the switch up with the accessory button in the panel title bar.
static const CGFloat trailingPadding = 8;
static const CGFloat verticalPadding = 8;
static const CGFloat spacing = 8;

@implementation ShareStatusBarView {
    FileSharing *_fileSharing;
    NSSwitch *_shareSwitch;
    NSTextField *_statusLabel;
}

- (instancetype)initWithFileSharing:(FileSharing *)fileSharing {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _fileSharing = fileSharing;
        _shareSwitch = [[NSSwitch alloc] init];
        _statusLabel = [NSTextField labelWithString:@""];
        NSTextField *titleLabel = [NSTextField labelWithString:@"File Sharing"];
        titleLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleBody options:@{}];
        [titleLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                             forOrientation:NSLayoutConstraintOrientationHorizontal];
        _statusLabel.font = [NSFont preferredFontForTextStyle:NSFontTextStyleSubheadline options:@{}];
        _statusLabel.textColor = NSColor.secondaryLabelColor;
        _statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _statusLabel.maximumNumberOfLines = 1;
        [_statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                               forOrientation:NSLayoutConstraintOrientationHorizontal];
        _shareSwitch.target = self;
        _shareSwitch.action = @selector(toggle);
        [_shareSwitch setAccessibilityLabel:@"File Sharing"];

        for (NSView *subview in @[titleLabel, _statusLabel, _shareSwitch]) {
            subview.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:subview];
        }
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leadingPadding],
            [titleLabel.centerYAnchor constraintEqualToAnchor:_shareSwitch.centerYAnchor],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:spacing],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_shareSwitch.leadingAnchor constant:-spacing],
            [_statusLabel.firstBaselineAnchor constraintEqualToAnchor:titleLabel.firstBaselineAnchor],
            [_shareSwitch.topAnchor constraintEqualToAnchor:self.topAnchor constant:verticalPadding],
            [_shareSwitch.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-trailingPadding],
            [_shareSwitch.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-verticalPadding],
        ]];
        [self setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(update)
                                                   name:FileSharing.didChangeNotification
                                                 object:fileSharing];
        [self update];
    }
    return self;
}

- (NSString *)statusText {
    if (_fileSharing.error) {
        return [NSString stringWithFormat:@"Snapshot failed: %@", _fileSharing.error.localizedDescription];
    }
    return _fileSharing.isSharing ? @"No device connected." : @"Not sharing.";
}

- (void)toggle {
    if (_shareSwitch.state == NSControlStateValueOn) {
        [_fileSharing start];
    } else {
        [_fileSharing stop];
    }
}

- (void)update {
    _shareSwitch.state = _fileSharing.isSharing ? NSControlStateValueOn : NSControlStateValueOff;
    _statusLabel.stringValue = self.statusText;
}

@end
#endif
