#import <XCTest/XCTest.h>

#import "Folder.h"
#import "NotificationCounter.h"
#import "Queue.h"
#import "Track.h"

@interface QueueTests : XCTestCase
@end

@implementation QueueTests {
    Track *_song;
    Track *_single;
}

- (void)setUp {
    [super setUp];
    _song = [[Track alloc] initWithTrackName:@"Song"
                                   albumName:@"Album"
                                  artistName:@"Artist"
                                        path:@"/Music/Artist/Album/Song.mp3"];
    _single = [[Track alloc] initWithTrackName:@"Single"
                                     albumName:@"Artist"
                                    artistName:Track.noArtist
                                          path:@"/Music/Artist/Single.m4a"];
}

- (void)testStartsEmpty {
    Queue *queue = [[Queue alloc] init];
    XCTAssertTrue(queue.isEmpty);
    XCTAssertEqual(queue.tracks.count, 0UL);
}

- (void)testAddingTrackAppendsIt {
    Queue *queue = [[Queue alloc] init];
    [queue add:_single];
    [queue add:_song];
    XCTAssertFalse(queue.isEmpty);
    XCTAssertEqualObjects(queue.tracks, (@[_single, _song]));
}

- (void)testAddingSameTrackTwiceQueuesTwoDistinctEntries {
    Queue *queue = [[Queue alloc] init];
    [queue add:_song];
    [queue add:_song];
    XCTAssertEqualObjects(queue.tracks, (@[_song, _song]));
    XCTAssertNotEqualObjects(queue.queuedTracks[0].identifier, queue.queuedTracks[1].identifier);
}

- (void)testAddingFolderAppendsTrackDescendantsInPreorder {
    Folder *folder = [[Folder alloc] initWithPath:@"/Music/Artist" name:@"Artist" children:@[
        [[Folder alloc] initWithPath:@"/Music/Artist/Album" name:@"Album" children:@[_song]],
        _single,
    ]];
    Queue *queue = [[Queue alloc] init];
    [queue add:folder];
    XCTAssertEqualObjects(queue.tracks, (@[_song, _single]));
}

- (void)testAddingEmptyFolderChangesNothing {
    Queue *queue = [[Queue alloc] init];
    [queue add:_song];
    [queue add:[[Folder alloc] init]];
    XCTAssertEqualObjects(queue.tracks, @[_song]);
}

- (void)testAddingChildrenDispatchesOnKind {
    Folder *album = [[Folder alloc] initWithPath:@"/Music/Artist/Album" name:@"Album" children:@[_song]];
    Queue *queue = [[Queue alloc] init];
    [queue addChildren:@[_single, album]];
    XCTAssertEqualObjects(queue.tracks, (@[_single, _song]));
}

- (void)testRemovingFirstDropsTheHeadOfTheQueue {
    Queue *queue = [[Queue alloc] init];
    [queue add:_song];
    [queue add:_single];
    [queue removeFirst];
    XCTAssertEqualObjects(queue.tracks, @[_single]);
}

- (void)testRemovingFirstFromEmptyQueueChangesNothing {
    Queue *queue = [[Queue alloc] init];
    [queue removeFirst];
    XCTAssertTrue(queue.isEmpty);
}

- (void)testClearingRemovesAllTracks {
    Queue *queue = [[Queue alloc] init];
    [queue add:_song];
    [queue add:_single];
    [queue clear];
    XCTAssertTrue(queue.isEmpty);
}

- (void)testMutationsPostDidChange {
    Queue *queue = [[Queue alloc] init];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Queue.didChangeNotification object:queue];
    [queue add:_song];
    [queue add:[[Folder alloc] initWithPath:@"/Music/Artist" name:@"Artist" children:@[_single]]];
    [queue removeFirst];
    [queue clear];
    XCTAssertEqual(changes.count, 4UL);
}

- (void)testAddingChildrenPostsOnce {
    Folder *album = [[Folder alloc] initWithPath:@"/Music/Artist/Album" name:@"Album" children:@[_song]];
    Queue *queue = [[Queue alloc] init];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Queue.didChangeNotification object:queue];
    [queue addChildren:@[_single, album]];
    XCTAssertEqualObjects(queue.tracks, (@[_single, _song]));
    XCTAssertEqual(changes.count, 1UL);
}

- (void)testAddingNothingPostsNothing {
    Queue *queue = [[Queue alloc] init];
    NotificationCounter *changes = [[NotificationCounter alloc] initWithName:Queue.didChangeNotification object:queue];
    [queue add:[[Folder alloc] init]];
    [queue removeFirst];
    [queue clear];
    XCTAssertEqual(changes.count, 0UL);
}

@end
