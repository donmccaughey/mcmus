#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "MusicLibraryStore.h"
#import "Player.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController <NSWindowDelegate>

- (instancetype)initWithStore:(MusicLibraryStore *)store
                       player:(Player *)player NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
