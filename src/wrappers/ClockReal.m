#import "ClockReal.h"


@interface ClockTimerReal : NSObject <ClockTimer>
@end


@implementation ClockTimerReal {
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


@implementation ClockReal


- (id<ClockTimer>)after:(NSTimeInterval)delay run:(void (^)(void))block;
{
    NSTimer *timer =
        [NSTimer scheduledTimerWithTimeInterval:delay
                                        repeats:NO
                                          block:^(NSTimer *fired) { block(); }];
    return [[ClockTimerReal alloc] initWithTimer:timer];
}


@end
