#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EmptyStateView : NSView

@property (nonatomic, copy) NSString *descriptionText;

- (instancetype)initWithTitle:(NSString *)title
                  systemImage:(NSString *)systemImage
                  description:(NSString *)description NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
