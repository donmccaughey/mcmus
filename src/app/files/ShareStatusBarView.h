#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "FileSharing.h"

NS_ASSUME_NONNULL_BEGIN

@interface ShareStatusBarView : NSView

@property (nonatomic, strong) FileSharing *fileSharing;
@property (nonatomic) BOOL libraryIsEmpty;

- (instancetype)initWithFileSharing:(FileSharing *)fileSharing
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
