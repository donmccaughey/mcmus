#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EmptyStateView : UIContentUnavailableView

@property (nonatomic, copy) NSString *descriptionText;

- (instancetype)initWithTitle:(NSString *)title
                  systemImage:(NSString *)systemImage
                  description:(NSString *)description NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithConfiguration:
    (UIContentUnavailableConfiguration *)configuration NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
