#import <Foundation/Foundation.h>

#import "Audio.h"
#import "Queue.h"
#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

@interface Player : NSObject

// Posted when isPlaying changes; timeIndex ticks twice a second while
// playing and no view shows it, so it posts nothing.
@property (class, nonatomic, readonly) NSNotificationName didChangeNotification;

@property (nonatomic, readonly) id<Audio> audio;
@property (nonatomic, readonly) Queue *queue;
@property (nonatomic, readonly) NSTimeInterval timeIndex;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly, nullable) Track *currentTrack;
@property (nonatomic, readonly, nullable) Track *nextTrack;

- (instancetype)initWithAudio:(id<Audio>)audio NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

- (void)play;
- (void)stop;
- (void)back;
- (void)next;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
