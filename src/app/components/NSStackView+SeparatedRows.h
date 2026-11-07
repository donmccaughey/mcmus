#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStackView (SeparatedRows)

+ (NSStackView *)headerOverBody:(NSView *)header body:(NSView *)body;
+ (NSStackView *)bodyOverFooter:(NSView *)body footer:(NSView *)footer;

@end

NS_ASSUME_NONNULL_END
#endif
