#import <XCTest/XCTest.h>

#import "AudioDemo.h"
#import "AudioFake.h"

@interface AudioDemoTests : XCTestCase
@end

@implementation AudioDemoTests {
    AudioFake *_audio;
    AudioDemo *_demo;
    NSURL *_demoTrackURL;
    NSURL *_first;
    NSURL *_second;
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    _audio = [AudioFake new];
    _demoTrackURL = [NSURL fileURLWithPath:@"/Bundle/demo-track.mp3" isDirectory:NO];
    _demo = [[AudioDemo alloc] initWithDemoTrackURL:_demoTrackURL audio:_audio];
    _first = [NSURL fileURLWithPath:@"/Users/demo/Music/First.mp3" isDirectory:NO];
    _second = [NSURL fileURLWithPath:@"/Users/demo/Music/Second.mp3" isDirectory:NO];
}

- (void)testPlaySubstitutesDemoTrackForBothTracks {
    [_demo play:_first from:12 thenPlay:_second];

    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_demoTrackURL from:12 thenPlay:_demoTrackURL]]);
}

- (void)testPlayWithoutNextTrackLeavesNextEmpty {
    [_demo play:_first from:0 thenPlay:nil];

    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_demoTrackURL from:0 thenPlay:nil]]);
}

- (void)testReplaceNextTrackSubstitutesDemoTrack {
    [_demo replaceNextTrackWith:_second];
    [_demo replaceNextTrackWith:nil];

    XCTAssertEqualObjects(_audio.calls, (@[
        [AudioFakeCall replaceNextTrack:_demoTrackURL],
        [AudioFakeCall replaceNextTrack:nil],
    ]));
}

- (void)testStopIsForwarded {
    [_demo stop];

    XCTAssertEqualObjects(_audio.calls, @[AudioFakeCall.stop]);
}

- (void)testPlaybackPositionComesFromWrappedAudio {
    _audio.playbackPosition = 42;

    XCTAssertEqual(_demo.playbackPosition, 42.0);
}

- (void)testTrackFinishedHandlerIsSetOnWrappedAudio {
    __block NSUInteger finished = 0;
    _demo.onTrackFinished = ^{
        finished += 1;
    };
    [_demo play:_first from:0 thenPlay:_second];

    [_audio finishCurrentTrack];

    XCTAssertEqual(finished, 1UL);
    XCTAssertNotNil(_demo.onTrackFinished);
}

- (void)testPlaybackPositionHandlerIsSetOnWrappedAudio {
    __block NSTimeInterval reported = 0;
    _demo.onPlaybackPositionChanged = ^(NSTimeInterval position) {
        reported = position;
    };

    [_audio reportPosition:7];

    XCTAssertEqual(reported, 7.0);
    XCTAssertNotNil(_demo.onPlaybackPositionChanged);
}

@end
