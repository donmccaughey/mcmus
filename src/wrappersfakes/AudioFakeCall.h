#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioFakeCall : NSObject

+ (AudioFakeCall *)play:(NSURL *)trackURL from:(NSTimeInterval)timeIndex thenPlay:(nullable NSURL *)nextTrackURL;
+ (AudioFakeCall *)replaceNextTrack:(nullable NSURL *)nextTrackURL;
@property (class, nonatomic, readonly) AudioFakeCall *stop;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
