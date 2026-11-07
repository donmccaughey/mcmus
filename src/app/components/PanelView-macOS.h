#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PanelView : NSView

- (instancetype)initWithTitle:(NSString *)title accessory:(nullable NSView *)accessory NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setContent:(NSView *)view;

@end

NS_ASSUME_NONNULL_END
#endif
