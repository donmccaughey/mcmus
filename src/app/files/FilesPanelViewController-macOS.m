#import "FilesPanelViewController-macOS.h"

#if TARGET_OS_OSX
#import "EmptyStateView-macOS.h"
#import "FilesTreeView.h"
#import "NSStackView+SeparatedRows.h"
#import "PanelView-macOS.h"
#import "ShareStatusBarView.h"

@implementation FilesPanelViewController {
    MusicLibraryStore *_store;
    NSButton *_findButton;
    EmptyStateView *_emptyFilesView;
    FilesTreeView *_treeView;
    NSStackView *_libraryView;
    PanelView *_panelView;
}

- (instancetype)initWithStore:(MusicLibraryStore *)store {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _findButton = [NSButton buttonWithTitle:@"Find" target:nil action:nil];
        _emptyFilesView = [[EmptyStateView alloc] initWithTitle:@"No music" systemImage:@"folder" description:@""];
        _treeView = [[FilesTreeView alloc] init];
        _libraryView = [NSStackView bodyOverFooter:_treeView footer:[[ShareStatusBarView alloc] init]];
        _panelView = [[PanelView alloc] initWithTitle:@"Files" accessory:_findButton];
    }
    return self;
}

- (void)loadView {
    _findButton.bezelStyle = NSBezelStylePush;
    _findButton.controlSize = NSControlSizeRegular;
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
    if (library.isEmpty) {
        _emptyFilesView.descriptionText = _store.loadDidFail
            ? @"The music library did not load."
            : @"The music library is empty.";
        [_panelView setContent:_emptyFilesView];
    } else {
        [_treeView setLibrary:library];
        [_panelView setContent:_libraryView];
    }
}

@end
#endif
