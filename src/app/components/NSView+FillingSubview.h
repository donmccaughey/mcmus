#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSView (FillingSubview)

- (void)addFillingSubview:(NSView *)view;

@end

NS_ASSUME_NONNULL_END
#endif
