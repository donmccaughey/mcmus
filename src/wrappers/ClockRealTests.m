#import <XCTest/XCTest.h>

#import "ClockReal.h"


static const void *queueKey = &queueKey;


@interface ClockRealTests : XCTestCase
@end


@implementation ClockRealTests {
    ClockReal *_clock;
    dispatch_queue_t _queue;
}


- (void)setUp;
{
    [super setUp];
    _clock = [ClockReal new];
    _queue = dispatch_queue_create("ClockRealTests", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_queue, queueKey, (void *)queueKey, NULL);
}


- (void)testQueueTimerRunsOnTheQueue;
{
    XCTestExpectation *ranOnQueue =
        [self expectationWithDescription:@"ran on queue"];

    [_clock after:0.01
          onQueue:_queue
              run:^{
                  if (dispatch_get_specific(queueKey)) [ranOnQueue fulfill];
              }];

    [self waitForExpectations:@[ranOnQueue] timeout:5];
}


- (void)testCancelledQueueTimerDoesNotRun;
{
    XCTestExpectation *ran = [self expectationWithDescription:@"ran"];
    ran.inverted = YES;

    id<ClockTimer> timer = [_clock after:0.05
                                 onQueue:_queue
                                     run:^{ [ran fulfill]; }];
    [timer cancel];

    [self waitForExpectations:@[ran] timeout:0.5];
}


@end
