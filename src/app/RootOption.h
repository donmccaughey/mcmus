#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


#if TARGET_OS_OSX
// Nil in demo mode, which ignores the `--root` option.
NSURL *_Nullable rootOptionURL(NSArray<NSString *> *arguments);
#endif


NS_ASSUME_NONNULL_END
