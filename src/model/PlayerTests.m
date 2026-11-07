#import <XCTest/XCTest.h>

#import "AudioFake.h"
#import "NotificationCounter.h"
#import "Player.h"
#import "Track.h"

@interface PlayerTests : XCTestCase
@end

@implementation PlayerTests {
    Track *_first;
    Track *_second;
    Track *_third;
    AudioFake *_audio;
}

- (void)setUp {
    [super setUp];
    _first = [[Track alloc] initWithTrackName:@"First" albumName:@"Album" artistName:@"Artist" path:@"/Music/Artist/Album/First.mp3"];
    _second = [[Track alloc] initWithTrackName:@"Second" albumName:@"Album" artistName:@"Artist" path:@"/Music/Artist/Album/Second.mp3"];
    _third = [[Track alloc] initWithTrackName:@"Third" albumName:@"Album" artistName:@"Artist" path:@"/Music/Artist/Album/Third.m4a"];
    _audio = [[AudioFake alloc] init];
}

- (Player *)makePlayer:(NSArray<Track *> *)tracks {
    Player *player = [[Player alloc] initWithAudio:_audio];
    for (Track *track in tracks) {
        [player.queue add:track];
    }
    return player;
}

- (Player *)makePlayingPlayer:(NSArray<Track *> *)tracks {
    Player *player = [self makePlayer:tracks];
    [player play];
    [_audio clearCalls];
    return player;
}

- (void)testNewPlayerIsStoppedWithEmptyQueue {
    Player *player = [self makePlayer:@[]];
    XCTAssertTrue(player.queue.isEmpty);
    XCTAssertNil(player.currentTrack);
    XCTAssertNil(player.nextTrack);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertFalse(player.isPlaying);
}

- (void)testCurrentAndNextTrackComeFromTheHeadOfTheQueue {
    XCTAssertEqualObjects([self makePlayer:@[_first]].currentTrack, _first);
    XCTAssertNil([self makePlayer:@[_first]].nextTrack);
    XCTAssertEqualObjects(([self makePlayer:@[_first, _second]].nextTrack), _second);
    XCTAssertEqualObjects(([self makePlayer:@[_first, _second, _third]].nextTrack), _second);
}

- (void)testCommandsAreIgnoredWhileQueueIsEmpty {
    Player *player = [self makePlayer:@[]];
    [player play];
    [player stop];
    [player back];
    [player next];
    [player clear];
    XCTAssertEqual(_audio.calls.count, 0UL);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertFalse(player.isPlaying);
}

- (void)testPlayStartsCurrentTrackAtTimeIndexWithNextTrack {
    Player *player = [self makePlayer:@[_first, _second, _third]];
    [player play];
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_first.url from:0 thenPlay:_second.url]]);
    XCTAssertTrue(player.isPlaying);
}

- (void)testPlayIsIgnoredWhileInPlayback {
    Player *player = [self makePlayingPlayer:@[_first]];
    [player play];
    XCTAssertEqual(_audio.calls.count, 0UL);
    XCTAssertTrue(player.isPlaying);
}

- (void)testStopRecordsPositionAndStopsAudio {
    Player *player = [self makePlayingPlayer:@[_first]];
    _audio.playbackPosition = 12.5;
    [player stop];
    XCTAssertEqualObjects(_audio.calls, @[AudioFakeCall.stop]);
    XCTAssertEqual(player.timeIndex, 12.5);
    XCTAssertFalse(player.isPlaying);
}

- (void)testStopIsIgnoredWhileStopped {
    Player *player = [self makePlayer:@[_first]];
    [player stop];
    XCTAssertEqual(_audio.calls.count, 0UL);
}

- (void)testPlayAfterStopResumesAtRecordedTimeIndex {
    Player *player = [self makePlayingPlayer:@[_first, _second]];
    _audio.playbackPosition = 30;
    [player stop];
    [_audio clearCalls];
    [player play];
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_first.url from:30 thenPlay:_second.url]]);
}

- (void)testBackWhileStoppedResetsTimeIndex {
    Player *player = [self makePlayingPlayer:@[_first]];
    _audio.playbackPosition = 5;
    [player stop];
    [_audio clearCalls];
    [player back];
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqual(_audio.calls.count, 0UL);
    XCTAssertEqualObjects(player.currentTrack, _first);
}

- (void)testBackWhileInPlaybackRestartsCurrentTrack {
    Player *player = [self makePlayingPlayer:@[_first, _second]];
    [_audio reportPosition:5];
    [player back];
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_first.url from:0 thenPlay:_second.url]]);
    XCTAssertTrue(player.isPlaying);
}

- (void)testNextWhileStoppedDiscardsCurrentTrack {
    Player *player = [self makePlayingPlayer:@[_first, _second]];
    _audio.playbackPosition = 5;
    [player stop];
    [_audio clearCalls];
    [player next];
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(player.queue.tracks, @[_second]);
    XCTAssertEqual(_audio.calls.count, 0UL);
    XCTAssertFalse(player.isPlaying);
}

- (void)testNextWhileInPlaybackWithNextTrackPlaysIt {
    Player *player = [self makePlayingPlayer:@[_first, _second, _third]];
    [player next];
    XCTAssertEqualObjects(player.queue.tracks, (@[_second, _third]));
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall play:_second.url from:0 thenPlay:_third.url]]);
    XCTAssertTrue(player.isPlaying);
}

- (void)testNextWhileInPlaybackWithoutNextTrackStops {
    Player *player = [self makePlayingPlayer:@[_first]];
    [player next];
    XCTAssertTrue(player.queue.isEmpty);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(_audio.calls, @[AudioFakeCall.stop]);
    XCTAssertFalse(player.isPlaying);
}

- (void)testClearWhileStoppedEmptiesQueue {
    Player *player = [self makePlayingPlayer:@[_first, _second]];
    _audio.playbackPosition = 5;
    [player stop];
    [_audio clearCalls];
    [player clear];
    XCTAssertTrue(player.queue.isEmpty);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqual(_audio.calls.count, 0UL);
}

- (void)testClearWhileInPlaybackStops {
    Player *player = [self makePlayingPlayer:@[_first, _second]];
    [player clear];
    XCTAssertTrue(player.queue.isEmpty);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(_audio.calls, @[AudioFakeCall.stop]);
    XCTAssertFalse(player.isPlaying);
}

- (void)testFinishedTrackIsRemovedAndNextTrackIsQueuedForAudio {
    Player *player = [self makePlayingPlayer:@[_first, _second, _third]];
    [_audio reportPosition:180];
    [_audio finishCurrentTrack];
    XCTAssertEqualObjects(player.queue.tracks, (@[_second, _third]));
    XCTAssertEqualObjects(player.currentTrack, _second);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall replaceNextTrack:_third.url]]);
    XCTAssertTrue(player.isPlaying);
}

- (void)testFinishedLastTrackEmptiesQueueAndStops {
    Player *player = [self makePlayingPlayer:@[_first]];
    [_audio finishCurrentTrack];
    XCTAssertTrue(player.queue.isEmpty);
    XCTAssertEqual(player.timeIndex, 0.0);
    XCTAssertFalse(player.isPlaying);
    XCTAssertEqual(_audio.calls.count, 0UL);
}

- (void)testPositionReportsUpdateTimeIndexWhileInPlayback {
    Player *player = [self makePlayingPlayer:@[_first]];
    [_audio reportPosition:42.25];
    XCTAssertEqual(player.timeIndex, 42.25);
}

- (void)testPositionReportsAreIgnoredWhileStopped {
    Player *player = [self makePlayer:@[_first]];
    [_audio reportPosition:42.25];
    XCTAssertEqual(player.timeIndex, 0.0);
}

- (void)testTrackAddedDuringPlaybackBecomesAudioNextTrack {
    Player *player = [self makePlayingPlayer:@[_first]];
    [player.queue add:_second];
    XCTAssertEqualObjects(_audio.calls, @[[AudioFakeCall replaceNextTrack:_second.url]]);
    [player.queue add:_third];
    XCTAssertEqualObjects(_audio.calls, (@[
        [AudioFakeCall replaceNextTrack:_second.url],
        [AudioFakeCall replaceNextTrack:_second.url],
    ]));
}

- (void)testTrackAddedWhileStoppedDoesNotTouchAudio {
    Player *player = [self makePlayer:@[_first]];
    [player.queue add:_second];
    XCTAssertEqual(_audio.calls.count, 0UL);
}

- (void)testPlayingAndStoppingEachPostDidChange {
    Player *player = [self makePlayer:@[_first]];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Player.didChangeNotification object:player];
    [player play];
    XCTAssertEqual(changes.count, 1UL);
    [player stop];
    XCTAssertEqual(changes.count, 2UL);
}

- (void)testPositionReportsDoNotPostDidChange {
    Player *player = [self makePlayingPlayer:@[_first]];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Player.didChangeNotification object:player];
    [_audio reportPosition:42.25];
    XCTAssertEqual(player.timeIndex, 42.25);
    XCTAssertEqual(changes.count, 0UL);
}

- (void)testFinishedLastTrackPostsDidChange {
    Player *player = [self makePlayingPlayer:@[_first]];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Player.didChangeNotification object:player];
    [_audio finishCurrentTrack];
    XCTAssertFalse(player.isPlaying);
    XCTAssertEqual(changes.count, 1UL);
}

@end
