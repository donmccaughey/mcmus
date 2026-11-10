#import <Foundation/Foundation.h>

#import "Audio.h"


NS_ASSUME_NONNULL_BEGIN


// Plays the demo track in place of every track, since demo tracks do not
// exist on disk.
@interface AudioDemo : NSObject <Audio>

- (instancetype)initWithDemoTrackURL:(NSURL *)demoTrackURL
                               audio:(id<Audio>)audio NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END
