#import "FolderChildCell.h"

#if TARGET_OS_IOS
#import "Folder.h"

// The leading inset spaces the symbols and widens their touch targets;
// no trailing inset keeps the last symbol on the cell's trailing margin.
static UIButton *makeRowButton(NSString *accessibilityLabel) {
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleMedium];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 0);
    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.accessibilityLabel = accessibilityLabel;
    return button;
}

static void setButtonImage(UIButton *button, NSString *systemImage) {
    UIButtonConfiguration *configuration = [button.configuration copy];
    configuration.image = [UIImage systemImageNamed:systemImage];
    button.configuration = configuration;
}

@implementation FolderChildCell {
    UIButton *_addButton;
    UIButton *_openButton;
    UIStackView *_accessoryStack;
    void (^_Nullable _onAdd)(void);
    void (^_Nullable _onOpen)(void);
}

+ (NSString *)reuseIdentifier {
    return @"FolderChildCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _addButton = makeRowButton(@"Add");
        _openButton = makeRowButton(@"Open");
        _accessoryStack = [[UIStackView alloc] init];
        __weak typeof(self) weakSelf = self;
        [_addButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [weakSelf add];
        }] forControlEvents:UIControlEventPrimaryActionTriggered];
        UIButtonConfiguration *openConfiguration = [_openButton.configuration copy];
        openConfiguration.image = [UIImage systemImageNamed:@"chevron.right"];
        openConfiguration.baseForegroundColor = UIColor.tertiaryLabelColor;
        _openButton.configuration = openConfiguration;
        [_openButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [weakSelf open];
        }] forControlEvents:UIControlEventPrimaryActionTriggered];
        [_accessoryStack addArrangedSubview:_addButton];
        [_accessoryStack addArrangedSubview:_openButton];
        self.accessoryView = _accessoryStack;
    }
    return self;
}

- (void)show:(id<FolderChild>)child onAdd:(void (^)(void))onAdd onOpen:(void (^)(void))onOpen {
    _onAdd = [onAdd copy];
    _onOpen = [onOpen copy];
    UIListContentConfiguration *content = [self defaultContentConfiguration];
    content.text = child.name;
    self.contentConfiguration = content;
    if ([child isKindOfClass:[Folder class]]) {
        setButtonImage(_addButton, @"plus.square");
        _openButton.hidden = NO;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        setButtonImage(_addButton, @"plus.circle");
        _openButton.hidden = YES;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    [self sizeAccessoryToFit];
}

- (void)add {
    if (_onAdd) {
        _onAdd();
    }
}

- (void)open {
    if (_onOpen) {
        _onOpen();
    }
}

// A cell places its accessory view by the view's frame and ignores its
// constraints.
- (void)sizeAccessoryToFit {
    CGRect frame = _accessoryStack.frame;
    frame.size = [_accessoryStack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    _accessoryStack.frame = frame;
}

@end
#endif
