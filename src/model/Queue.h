#import <Foundation/Foundation.h>

#import "FolderChild.h"
#import "QueuedTrack.h"
#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

@interface Queue : NSObject

@property (class, nonatomic, readonly) NSNotificationName didChangeNotification;

@property (nonatomic, readonly, copy) NSArray<QueuedTrack *> *queuedTracks;
@property (nonatomic, readonly) NSArray<Track *> *tracks;
@property (nonatomic, readonly) BOOL isEmpty;

- (void)add:(id<FolderChild>)child;
- (void)addChildren:(NSArray<id<FolderChild>> *)children;
- (void)removeFirst;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
