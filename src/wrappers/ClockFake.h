#import <Foundation/Foundation.h>

#import "Clock.h"

NS_ASSUME_NONNULL_BEGIN

@interface ClockFake : NSObject <Clock>

@property (nonatomic, readonly) NSUInteger pendingTimerCount;
// The current time before the fake time is advanced.
@property (nonatomic) time_t startTime;

// Moves the fake time forward, running the timers that come due in the order
// they are due, including timers scheduled by the blocks that run. The current
// time moves forward with it.
//
// Every block runs on the calling thread, including blocks scheduled with
// -after:onQueue:run:, so call this from the queue those blocks expect.
- (void)advance:(NSTimeInterval)interval;

@end

NS_ASSUME_NONNULL_END
