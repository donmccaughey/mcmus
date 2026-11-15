#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ClockTimer <NSObject>

- (void)cancel;

@end

@protocol Clock <NSObject>

// The block runs once, on the run loop of the calling thread, unless the
// timer is cancelled first.
- (id<ClockTimer>)after:(NSTimeInterval)delay run:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
