#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Audio <NSObject>

@property (nonatomic, readonly) NSTimeInterval playbackPosition;
@property (nonatomic, copy, nullable) void (^onTrackFinished)(void);
@property (nonatomic, copy, nullable) void (^onPlaybackPositionChanged)
    (NSTimeInterval position);

- (void)play:(NSURL *)trackURL
        from:(NSTimeInterval)timeIndex
    thenPlay:(nullable NSURL *)nextTrackURL;
- (void)replaceNextTrackWith:(nullable NSURL *)nextTrackURL;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
