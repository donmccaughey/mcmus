#import "ClockReal.h"


@interface ClockRunLoopTimerReal : NSObject <ClockTimer>
@end


@implementation ClockRunLoopTimerReal {
    NSTimer *_timer;
}


- (instancetype)initWithTimer:(NSTimer *)timer;
{
    self = [super init];
    if (!self) return nil;

    _timer = timer;

    return self;
}


- (void)cancel;
{
    [_timer invalidate];
}


@end


@interface ClockQueueTimerReal : NSObject <ClockTimer>
@end


@implementation ClockQueueTimerReal {
    dispatch_block_t _dispatchBlock;
}


- (instancetype)initWithDispatchBlock:(dispatch_block_t)dispatchBlock;
{
    self = [super init];
    if (!self) return nil;

    _dispatchBlock = dispatchBlock;

    return self;
}


- (void)cancel;
{
    dispatch_block_cancel(_dispatchBlock);
}


@end


@implementation ClockReal


- (id<ClockTimer>)after:(NSTimeInterval)delay run:(void (^)(void))block;
{
    NSTimer *timer =
        [NSTimer scheduledTimerWithTimeInterval:delay
                                        repeats:NO
                                          block:^(NSTimer *fired) { block(); }];
    return [[ClockRunLoopTimerReal alloc] initWithTimer:timer];
}


- (id<ClockTimer>)after:(NSTimeInterval)delay
                onQueue:(dispatch_queue_t)queue
                    run:(void (^)(void))block;
{
    dispatch_block_flags_t flags = 0;
    dispatch_block_t dispatchBlock = dispatch_block_create(flags, block);
    NSAssert(dispatchBlock, @"Expected to create dispatchBlock");

    dispatch_time_t dueTime =
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(dueTime, queue, dispatchBlock);

    return [[ClockQueueTimerReal alloc] initWithDispatchBlock:dispatchBlock];
}


- (time_t)currentTime;
{
    return time(NULL);
}


@end
