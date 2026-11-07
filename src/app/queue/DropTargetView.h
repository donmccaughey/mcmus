#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

@interface DropTargetView : NSView

@property (nonatomic, copy, nullable) void (^onDrop)(NSArray<id<FolderChild>> *children);

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setContent:(NSView *)view;

@end

NS_ASSUME_NONNULL_END
#endif
