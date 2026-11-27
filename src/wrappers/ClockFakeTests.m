#import <XCTest/XCTest.h>

#import "ClockFake.h"


@interface ClockFakeTests : XCTestCase
@end


@implementation ClockFakeTests {
    ClockFake *_clock;
    NSMutableArray<NSString *> *_fired;
}


- (void)setUp;
{
    [super setUp];
    _clock = [ClockFake new];
    _fired = [NSMutableArray new];
}


- (void)after:(NSTimeInterval)delay record:(NSString *)name;
{
    NSMutableArray<NSString *> *fired = _fired;
    [_clock after:delay run:^{ [fired addObject:name]; }];
}


- (void)testTimerDoesNotRunBeforeItIsDue;
{
    [self after:10 record:@"ten"];

    [_clock advance:9.5];

    XCTAssertEqualObjects(_fired, @[]);
    XCTAssertEqual(_clock.pendingTimerCount, 1UL);
}


- (void)testTimerRunsOnceWhenDue;
{
    [self after:10 record:@"ten"];

    [_clock advance:10];
    [_clock advance:10];

    XCTAssertEqualObjects(_fired, @[@"ten"]);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testAdvancesAccumulate;
{
    [self after:10 record:@"ten"];

    [_clock advance:6];
    [_clock advance:6];

    XCTAssertEqualObjects(_fired, @[@"ten"]);
}


- (void)testTimersRunInDueOrder;
{
    [self after:10 record:@"ten"];
    [self after:5 record:@"five"];

    [_clock advance:20];

    XCTAssertEqualObjects(_fired, (@[@"five", @"ten"]));
}


- (void)testCancelledTimerDoesNotRun;
{
    NSMutableArray<NSString *> *fired = _fired;
    id<ClockTimer> timer = [_clock after:10 run:^{ [fired addObject:@"ten"]; }];

    [timer cancel];
    [_clock advance:20];

    XCTAssertEqualObjects(_fired, @[]);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testQueueTimerRunsOnAdvance;
{
    NSMutableArray<NSString *> *fired = _fired;
    dispatch_queue_t queue = dispatch_queue_create(
        "ClockFakeTests", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
    );
    [_clock after:10 onQueue:queue run:^{ [fired addObject:@"ten"]; }];

    [_clock advance:10];

    XCTAssertEqualObjects(_fired, @[@"ten"]);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testCancelledQueueTimerDoesNotRun;
{
    NSMutableArray<NSString *> *fired = _fired;
    dispatch_queue_t queue = dispatch_queue_create(
        "ClockFakeTests", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
    );
    id<ClockTimer> timer = [_clock after:10
                                 onQueue:queue
                                     run:^{ [fired addObject:@"ten"]; }];

    [timer cancel];
    [_clock advance:20];

    XCTAssertEqualObjects(_fired, @[]);
    XCTAssertEqual(_clock.pendingTimerCount, 0UL);
}


- (void)testTimerScheduledByARunningTimerIsMeasuredFromThatTimersDueTime;
{
    ClockFake *clock = _clock;
    NSMutableArray<NSString *> *fired = _fired;
    [_clock after:5
              run:^{
                  [fired addObject:@"first"];
                  [clock after:5 run:^{ [fired addObject:@"second"]; }];
              }];

    [_clock advance:9];
    XCTAssertEqualObjects(_fired, @[@"first"]);

    [_clock advance:1];
    XCTAssertEqualObjects(_fired, (@[@"first", @"second"]));
}


- (void)testCurrentTimeIsTheStartTimeBeforeAdvancing;
{
    _clock.startTime = 1700000000;

    XCTAssertEqual([_clock currentTime], (time_t)1700000000);
}


- (void)testCurrentTimeMovesForwardWithAdvance;
{
    _clock.startTime = 1700000000;

    [_clock advance:90];

    XCTAssertEqual([_clock currentTime], (time_t)1700000090);
}


@end
