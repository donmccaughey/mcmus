#import "FilesTreeView.h"

#if TARGET_OS_OSX
#import "FilesTreeNode.h"
#import "Folder.h"
#import "FolderChildPasteboard.h"

static NSUserInterfaceItemIdentifier const cellIdentifier = @"FilesTreeCell";

static NSTableCellView *makeCell(void) {
    NSTableCellView *cell = [[NSTableCellView alloc] init];
    cell.identifier = cellIdentifier;

    NSImageView *imageView = [[NSImageView alloc] init];
    imageView.contentTintColor = NSColor.controlAccentColor;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:imageView];
    cell.imageView = imageView;

    NSTextField *textField = [NSTextField labelWithString:@""];
    textField.lineBreakMode = NSLineBreakByTruncatingTail;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:textField];
    cell.textField = textField;

    [NSLayoutConstraint activateConstraints:@[
        [imageView.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        [imageView.widthAnchor constraintEqualToConstant:20],
        [textField.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:4],
        [textField.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
        [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    ]];
    return cell;
}

@interface FilesTreeDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, copy) NSArray<FilesTreeNode *> *nodes;

@end

@implementation FilesTreeDataSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _nodes = @[];
    }
    return self;
}

- (NSArray<FilesTreeNode *> *)childrenOfItem:(nullable id)item {
    return [item isKindOfClass:[FilesTreeNode class]] ? ((FilesTreeNode *)item).children : _nodes;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    return [self childrenOfItem:item].count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    return [self childrenOfItem:item][index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[FilesTreeNode class]] && ((FilesTreeNode *)item).isExpandable;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView
              viewForTableColumn:(nullable NSTableColumn *)tableColumn
                            item:(id)item {
    if (![item isKindOfClass:[FilesTreeNode class]]) {
        return nil;
    }
    FilesTreeNode *node = item;
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:cellIdentifier owner:nil] ?: makeCell();
    cell.imageView.image = [NSImage imageWithSystemSymbolName:node.systemImage accessibilityDescription:nil];
    cell.textField.stringValue = node.name;
    return cell;
}

- (nullable id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item {
    if (![item isKindOfClass:[FilesTreeNode class]]) {
        return nil;
    }
    return [FolderChildPasteboard pasteboardItemForChild:((FilesTreeNode *)item).child];
}

@end

@implementation FilesTreeView {
    NSOutlineView *_outlineView;
    FilesTreeDataSource *_dataSource;
}

- (instancetype)init {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _outlineView = [[NSOutlineView alloc] init];
        _dataSource = [[FilesTreeDataSource alloc] init];
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        [_outlineView addTableColumn:column];
        _outlineView.outlineTableColumn = column;
        _outlineView.headerView = nil;
        _outlineView.style = NSTableViewStyleInset;
        _outlineView.usesAlternatingRowBackgroundColors = NO;
        _outlineView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
        [_outlineView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
        _outlineView.dataSource = _dataSource;
        _outlineView.delegate = _dataSource;
        self.documentView = _outlineView;
        self.hasVerticalScroller = YES;
    }
    return self;
}

- (void)setLibrary:(MusicLibrary *)library {
    NSArray<id<FolderChild>> *children = library.rootFolder.children;
    NSMutableArray<FilesTreeNode *> *nodes = [NSMutableArray arrayWithCapacity:children.count];
    for (id<FolderChild> child in children) {
        [nodes addObject:[[FilesTreeNode alloc] initWithChild:child]];
    }
    _dataSource.nodes = nodes;
    [_outlineView reloadData];
}

@end
#endif
