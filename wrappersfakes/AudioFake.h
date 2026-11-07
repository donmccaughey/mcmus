#import <Foundation/Foundation.h>

#import "Audio.h"
#import "AudioFakeCall.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioFake : NSObject <Audio>

@property (nonatomic, readonly, copy) NSArray<AudioFakeCall *> *calls;
@property (nonatomic) NSTimeInterval playbackPosition;

- (void)clearCalls;
- (void)finishCurrentTrack;
- (void)reportPosition:(NSTimeInterval)position;

@end

NS_ASSUME_NONNULL_END
