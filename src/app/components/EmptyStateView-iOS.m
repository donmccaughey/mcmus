#import "EmptyStateView-iOS.h"

#if TARGET_OS_IOS
@implementation EmptyStateView

- (instancetype)initWithTitle:(NSString *)title
                  systemImage:(NSString *)systemImage
                  description:(NSString *)description
{
    UIContentUnavailableConfiguration *configuration =
        [UIContentUnavailableConfiguration emptyConfiguration];
    configuration.image = [UIImage systemImageNamed:systemImage];
    configuration.text = title;
    configuration.secondaryText = description;
    return [super initWithConfiguration:configuration];
}

- (NSString *)descriptionText
{
    return self.unavailableConfiguration.secondaryText ?: @"";
}

- (void)setDescriptionText:(NSString *)descriptionText
{
    UIContentUnavailableConfiguration *updated =
        [self.unavailableConfiguration copy];
    updated.secondaryText = descriptionText;
    self.configuration = updated;
}

- (UIContentUnavailableConfiguration *)unavailableConfiguration
{
    return (UIContentUnavailableConfiguration *)self.configuration;
}

@end
#endif
