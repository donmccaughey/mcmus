#import "PlayerPanelView-iOS.h"

#if TARGET_OS_IOS
static const CGFloat buttonWidth = 68;
static const CGFloat buttonSpacing = 8;
static const CGFloat padding = 16;

static CGFloat playStopButtonWidth(void)
{
    return buttonWidth * 1.2;
}

static UIButton *makeButton(NSString *systemImage, NSString *accessibilityLabel)
{
    UIButtonConfiguration *configuration =
        [UIButtonConfiguration borderedButtonConfiguration];
    configuration.image = [UIImage systemImageNamed:systemImage];
    configuration.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration
            configurationWithTextStyle:UIFontTextStyleBody
                                 scale:UIImageSymbolScaleMedium];
    UIButton *button = [UIButton buttonWithConfiguration:configuration
                                           primaryAction:nil];
    button.accessibilityLabel = accessibilityLabel;
    // The buttons' height sets the panel's, so the queue table below
    // has to be what stretches to fill the queue panel.
    [button setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisVertical];
    [button
        setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisVertical];
    return button;
}

@implementation PlayerPanelView {
    Player *_player;
    UIButton *_backButton;
    UIButton *_playStopButton;
    UIButton *_nextButton;
}

- (instancetype)initWithPlayer:(Player *)player
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _player = player;
        _backButton = makeButton(@"backward.fill", @"Back");
        _playStopButton = makeButton(@"play.fill", @"Play");
        _nextButton = makeButton(@"forward.fill", @"Next");
        [_backButton addAction:[UIAction actionWithHandler:^(
                                   UIAction *action) { [player back]; }]
              forControlEvents:UIControlEventPrimaryActionTriggered];
        [_playStopButton
                   addAction:[UIAction actionWithHandler:^(UIAction *action) {
                       if (player.isPlaying) {
                           [player stop];
                       } else {
                           [player play];
                       }
                   }]
            forControlEvents:UIControlEventPrimaryActionTriggered];
        [_nextButton addAction:[UIAction actionWithHandler:^(
                                   UIAction *action) { [player next]; }]
              forControlEvents:UIControlEventPrimaryActionTriggered];

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
            _backButton, _playStopButton, _nextButton
        ]];
        stack.spacing = buttonSpacing;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        self.directionalLayoutMargins =
            NSDirectionalEdgeInsetsMake(padding, padding, padding, padding);
        UILayoutGuide *margins = self.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_backButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [_playStopButton.widthAnchor
                constraintEqualToConstant:playStopButtonWidth()],
            [_nextButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [stack.centerXAnchor constraintEqualToAnchor:margins.centerXAnchor],
            [stack.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [stack.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
        ]];

        // The buttons have fixed widths, and at larger sizes than this the
        // symbols outgrow them.
        self.maximumContentSizeCategory =
            UIContentSizeCategoryAccessibilityLarge;

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(update)
                       name:Queue.didChangeNotification
                     object:player.queue];
        [center addObserver:self
                   selector:@selector(update)
                       name:Player.didChangeNotification
                     object:player];
        [self update];
    }
    return self;
}

- (void)update
{
    BOOL isEnabled = !_player.queue.isEmpty;
    for (UIButton *button in @[_backButton, _playStopButton, _nextButton]) {
        button.enabled = isEnabled;
    }
    UIButtonConfiguration *configuration = [_playStopButton.configuration copy];
    if (_player.isPlaying) {
        configuration.image = [UIImage systemImageNamed:@"stop.fill"];
        _playStopButton.accessibilityLabel = @"Stop";
    } else {
        configuration.image = [UIImage systemImageNamed:@"play.fill"];
        _playStopButton.accessibilityLabel = @"Play";
    }
    _playStopButton.configuration = configuration;
}

@end
#endif
