#import "ClockFake.h"


@interface ClockTimerFake : NSObject <ClockTimer>

@property (nonatomic, readonly) NSTimeInterval dueTime;
@property (nonatomic, readonly) void (^block)(void);
@property (nonatomic, readonly) BOOL isCancelled;

@end


@implementation ClockTimerFake


- (instancetype)initWithDueTime:(NSTimeInterval)dueTime
                          block:(void (^)(void))block;
{
    self = [super init];
    if (!self) return nil;

    _dueTime = dueTime;
    _block = [block copy];

    return self;
}


- (void)cancel;
{
    _isCancelled = YES;
}


@end


@implementation ClockFake {
    NSTimeInterval _now;
    NSMutableArray<ClockTimerFake *> *_timers;
}


- (instancetype)init;
{
    self = [super init];
    if (!self) return nil;

    _timers = [NSMutableArray new];

    return self;
}


- (NSUInteger)pendingTimerCount;
{
    [self discardCancelledTimers];
    return _timers.count;
}


- (id<ClockTimer>)after:(NSTimeInterval)delay run:(void (^)(void))block;
{
    ClockTimerFake *timer = [[ClockTimerFake alloc] initWithDueTime:_now + delay
                                                              block:block];
    [_timers addObject:timer];
    return timer;
}


- (id<ClockTimer>)after:(NSTimeInterval)delay
                onQueue:(dispatch_queue_t)queue
                    run:(void (^)(void))block;
{
    return [self after:delay run:block];
}


- (time_t)currentTime;
{
    return _startTime + (time_t)_now;
}


- (void)advance:(NSTimeInterval)interval;
{
    NSTimeInterval end = _now + interval;
    ClockTimerFake *timer;
    while ((timer = [self nextTimerDueBy:end])) {
        [_timers removeObjectIdenticalTo:timer];
        _now = timer.dueTime;
        timer.block();
    }
    _now = end;
}


- (nullable ClockTimerFake *)nextTimerDueBy:(NSTimeInterval)end;
{
    [self discardCancelledTimers];
    ClockTimerFake *next = nil;
    for (ClockTimerFake *timer in _timers) {
        if (timer.dueTime > end) continue;
        if (!next || timer.dueTime < next.dueTime) next = timer;
    }
    return next;
}


- (void)discardCancelledTimers;
{
    NSIndexSet *cancelled =
        [_timers indexesOfObjectsPassingTest:^BOOL(
                     ClockTimerFake *timer, NSUInteger index, BOOL *stop
        ) { return timer.isCancelled; }];
    [_timers removeObjectsAtIndexes:cancelled];
}


@end
