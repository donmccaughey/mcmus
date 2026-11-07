#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#import "MusicLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilesTreeView : NSScrollView

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setLibrary:(MusicLibrary *)library;

@end

NS_ASSUME_NONNULL_END
#endif
