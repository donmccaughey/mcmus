#import "ShareStatusBarView.h"

#if TARGET_OS_OSX
static const CGFloat leadingPadding = 16;
// Lines the switch up with the accessory button in the panel title bar.
static const CGFloat trailingPadding = 8;
static const CGFloat verticalPadding = 8;
static const CGFloat spacing = 8;
static const CGFloat spinnerSize = 16;

// A small library's snapshot finishes well inside this delay, so the label
// never flickers through the in-progress text; a large library's snapshot
// outlasts it and gets feedback.
static const NSTimeInterval showProgressDelay = 0.75;
// Stops a one-frame blink when the snapshot finishes just after the delay.
static const NSTimeInterval minimumProgressDuration = 0.5;

@implementation ShareStatusBarView {
    FileSharing *_fileSharing;
    NSSwitch *_shareSwitch;
    NSTextField *_statusLabel;
    NSProgressIndicator *_spinner;
    NSTimer *_showProgressTimer;
    NSDate *_progressShownAt;
}

- (instancetype)initWithFileSharing:(FileSharing *)fileSharing {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _fileSharing = fileSharing;
        _shareSwitch = [[NSSwitch alloc] init];
        _statusLabel = [NSTextField labelWithString:@""];
        _spinner = [[NSProgressIndicator alloc] init];
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
        _spinner.style = NSProgressIndicatorStyleSpinning;
        _spinner.controlSize = NSControlSizeSmall;
        _spinner.indeterminate = YES;
        _spinner.displayedWhenStopped = NO;
        _shareSwitch.target = self;
        _shareSwitch.action = @selector(toggle);
        [_shareSwitch setAccessibilityLabel:@"File Sharing"];

        for (NSView *subview in @[titleLabel, _statusLabel, _spinner, _shareSwitch]) {
            subview.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:subview];
        }
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leadingPadding],
            [titleLabel.centerYAnchor constraintEqualToAnchor:_shareSwitch.centerYAnchor],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:spacing],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_spinner.leadingAnchor constant:-spacing],
            [_statusLabel.firstBaselineAnchor constraintEqualToAnchor:titleLabel.firstBaselineAnchor],
            [_spinner.widthAnchor constraintEqualToConstant:spinnerSize],
            [_spinner.heightAnchor constraintEqualToConstant:spinnerSize],
            [_spinner.centerYAnchor constraintEqualToAnchor:_shareSwitch.centerYAnchor],
            [_spinner.trailingAnchor constraintEqualToAnchor:_shareSwitch.leadingAnchor constant:-spacing],
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

- (NSString *)progressText {
    return FileSharingStateStarting == _fileSharing.state ? @"Creating snapshot…" : @"Removing snapshot…";
}

- (NSControlStateValue)switchState {
    switch (_fileSharing.state) {
        case FileSharingStateStarting:
        case FileSharingStateSharing:
            return NSControlStateValueOn;
        case FileSharingStateOff:
        case FileSharingStateStopping:
            return NSControlStateValueOff;
    }
}

- (void)toggle {
    if (_fileSharing.isChanging) {
        _shareSwitch.state = self.switchState;
        return;
    }
    if (_shareSwitch.state == NSControlStateValueOn) {
        [_fileSharing start];
    } else {
        [_fileSharing stop];
    }
}

- (void)update {
    if (_fileSharing.isChanging) {
        [self beginChange];
    } else {
        [self finishChange];
    }
}

- (void)beginChange {
    _shareSwitch.enabled = NO;
    _shareSwitch.state = self.switchState;
    if (_progressShownAt) {
        _statusLabel.stringValue = self.progressText;
    } else if ( ! _showProgressTimer) {
        _showProgressTimer = [NSTimer scheduledTimerWithTimeInterval:showProgressDelay
                                                              target:self
                                                            selector:@selector(showProgress)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)showProgress {
    _showProgressTimer = nil;
    _progressShownAt = [NSDate date];
    _statusLabel.stringValue = self.progressText;
    [_spinner startAnimation:nil];
}

- (void)finishChange {
    [_showProgressTimer invalidate];
    _showProgressTimer = nil;

    NSTimeInterval remaining = self.remainingProgressDuration;
    if (remaining > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if ( ! self->_fileSharing.isChanging) {
                [self finishChange];
            }
        });
        return;
    }

    [_spinner stopAnimation:nil];
    _progressShownAt = nil;
    _shareSwitch.enabled = YES;
    _shareSwitch.state = self.switchState;
    _statusLabel.stringValue = self.statusText;
}

- (NSTimeInterval)remainingProgressDuration {
    if ( ! _progressShownAt) return 0;
    return minimumProgressDuration + _progressShownAt.timeIntervalSinceNow;
}

@end
#endif
