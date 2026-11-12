#import "DropTargetView.h"

#if TARGET_OS_OSX
#import "FolderChildPasteboard.h"
#import "NSView+FillingSubview.h"

@implementation DropTargetView {
    NSView *_Nullable _contentView;
}

- (instancetype)init
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        [self registerForDraggedTypes:@[FolderChildPasteboardType]];
    }
    return self;
}

- (void)setContent:(NSView *)view
{
    if (view == _contentView) {
        return;
    }
    [_contentView removeFromSuperview];
    _contentView = view;
    [self addFillingSubview:view];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSArray<id<FolderChild>> *children =
        [FolderChildPasteboard childrenInPasteboard:sender.draggingPasteboard];
    if (children.count == 0) {
        return NO;
    }
    if (_onDrop) {
        _onDrop(children);
    }
    return YES;
}

@end
#endif
