#import "SettingsWindowController.h"

#if TARGET_OS_OSX
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "ReadOnlyTextField.h"

static const CGFloat contentWidth = 600;
static const CGFloat padding = 16;

@implementation SettingsWindowController {
    MusicLibraryStore *_store;
    ReadOnlyTextField *_pathField;
    NSButton *_chooseButton;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, contentWidth, 0)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"MC Mus Settings";
    window.restorable = NO;
    window.releasedWhenClosed = NO;
    self = [super initWithWindow:window];
    if (self) {
        _store = store;
        _pathField = [[ReadOnlyTextField alloc] init];
        _chooseButton = [NSButton buttonWithTitle:@"Choose…" target:self action:@selector(chooseMusicRootDirectory)];
        _chooseButton.bezelStyle = NSBezelStylePush;
        NSView *contentView = [self makeContentView];
        [window setContentSize:contentView.fittingSize];
        window.contentView = contentView;
        [window center];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(update)
                                                   name:MusicLibraryStore.musicRootDirectoryDidChangeNotification
                                                 object:store];
        [self update];
    }
    return self;
}

- (NSView *)makeContentView {
    NSTextField *label = [NSTextField labelWithString:@"Music Files:"];
    NSStackView *row = [NSStackView stackViewWithViews:@[label, _pathField, _chooseButton]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeFirstBaseline;
    row.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *contentView = [[NSView alloc] init];
    [contentView addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [contentView.widthAnchor constraintEqualToConstant:contentWidth],
        [row.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:padding],
        [row.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:padding],
        [row.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-padding],
        [row.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-padding],
    ]];
    return contentView;
}

- (void)update {
    [_pathField setText:_store.musicRootDirectory.url.path ?: @""];
}

- (void)chooseMusicRootDirectory {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    panel.directoryURL = _store.musicRootDirectory.url;
    // Dims files that are not music so the user can see which directories hold music.
    panel.allowedContentTypes = @[UTTypeMP3, UTTypeMPEG4Audio];
    if ([panel runModal] != NSModalResponseOK || !panel.URL) {
        return;
    }
    [_store changeMusicRootDirectoryTo:panel.URL];
}

@end
#endif
