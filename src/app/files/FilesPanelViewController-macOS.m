#import "FilesPanelViewController-macOS.h"

#if TARGET_OS_OSX
#import "EmptyStateView-macOS.h"
#import "FileSharing.h"
#import "FilesTreeView.h"
#import "NSStackView+SeparatedRows.h"
#import "NSView+FillingSubview.h"
#import "PanelView-macOS.h"
#import "ShareStatusBarView.h"

@implementation FilesPanelViewController {
    MusicLibraryStore *_store;
    FileSharing *_fileSharing;
    NSButton *_findButton;
    EmptyStateView *_emptyFilesView;
    FilesTreeView *_treeView;
    ShareStatusBarView *_shareStatusBar;
    PanelView *_panelView;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _fileSharing = [[FileSharing alloc] initWithStore:store];
        _findButton = [NSButton buttonWithTitle:@"Find" target:nil action:nil];
        _emptyFilesView = [[EmptyStateView alloc] initWithTitle:@"No music" systemImage:@"folder" description:@""];
        _treeView = [[FilesTreeView alloc] init];
        _panelView = [[PanelView alloc] initWithTitle:@"Files" accessory:_findButton];
    }
    return self;
}

- (void)loadView {
    _findButton.bezelStyle = NSBezelStylePush;
    _findButton.controlSize = NSControlSizeRegular;
    NSView *filesBody = [[NSView alloc] init];
    [filesBody addFillingSubview:_emptyFilesView];
    [filesBody addFillingSubview:_treeView];
    _shareStatusBar = [[ShareStatusBarView alloc] initWithFileSharing:_fileSharing];
    [_panelView setContent:[NSStackView bodyOverFooter:filesBody footer:_shareStatusBar]];
    self.view = _panelView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(update)
                                               name:MusicLibraryStore.libraryDidChangeNotification
                                             object:_store];
    [self update];
}

- (void)update {
    MusicLibrary *library = _store.library;
    _findButton.enabled = !library.isEmpty;
    _shareStatusBar.libraryIsEmpty = library.isEmpty;
    _emptyFilesView.hidden = !library.isEmpty;
    _treeView.hidden = library.isEmpty;
    if (library.isEmpty) {
        _emptyFilesView.descriptionText = _store.loadDidFail
            ? @"The music library did not load."
            : @"The music library is empty.";
    } else {
        [_treeView setLibrary:library];
    }
}

@end
#endif
