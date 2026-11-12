#import "PlayerPanelView-macOS.h"

#if TARGET_OS_OSX
static const CGFloat buttonWidth = 60;
static const CGFloat padding = 16;

static CGFloat playStopButtonWidth(void)
{
    return buttonWidth * 1.2;
}

static NSImage *symbolImage(NSString *systemImage, NSString *title)
{
    return [NSImage imageWithSystemSymbolName:systemImage
                     accessibilityDescription:title];
}

static NSButton *makeButton(NSString *systemImage, NSString *title)
{
    NSButton *button = [NSButton buttonWithImage:symbolImage(systemImage, title)
                                          target:nil
                                          action:nil];
    button.bezelStyle = NSBezelStylePush;
    [button setAccessibilityTitle:title];
    return button;
}

@implementation PlayerPanelView {
    Player *_player;
    NSButton *_backButton;
    NSButton *_playStopButton;
    NSButton *_nextButton;
}

- (instancetype)initWithPlayer:(Player *)player
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _player = player;
        _backButton = makeButton(@"backward.fill", @"Back");
        _playStopButton = makeButton(@"play.fill", @"Play");
        _nextButton = makeButton(@"forward.fill", @"Next");
        _backButton.target = self;
        _backButton.action = @selector(back);
        _playStopButton.target = self;
        _playStopButton.action = @selector(playOrStop);
        _nextButton.target = self;
        _nextButton.action = @selector(next);

        NSStackView *stack = [NSStackView
            stackViewWithViews:@[_backButton, _playStopButton, _nextButton]];
        stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [_backButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [_playStopButton.widthAnchor
                constraintEqualToConstant:playStopButtonWidth()],
            [_nextButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stack.topAnchor constraintEqualToAnchor:self.topAnchor
                                            constant:padding],
            [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor
                                               constant:-padding],
        ]];
        [self setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationVertical];

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(update)
                       name:Queue.didChangeNotification
                     object:player.queue];
        [center addObserver:self selector:@selector(update)
                       name:Player.didChangeNotification
                     object:player];
        [self update];
    }
    return self;
}

- (void)update
{
    BOOL isEnabled = !_player.queue.isEmpty;
    for (NSButton *button in @[_backButton, _playStopButton, _nextButton]) {
        button.enabled = isEnabled;
    }
    if (_player.isPlaying) {
        _playStopButton.image = symbolImage(@"stop.fill", @"Stop");
        [_playStopButton setAccessibilityTitle:@"Stop"];
    } else {
        _playStopButton.image = symbolImage(@"play.fill", @"Play");
        [_playStopButton setAccessibilityTitle:@"Play"];
    }
}

- (void)back
{
    [_player back];
}

- (void)playOrStop
{
    if (_player.isPlaying) {
        [_player stop];
    } else {
        [_player play];
    }
}

- (void)next
{
    [_player next];
}

@end
#endif
