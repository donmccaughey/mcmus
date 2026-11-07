#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

NSMenu *makeMainMenu(id settingsTarget, SEL settingsAction);

NS_ASSUME_NONNULL_END
#endif
