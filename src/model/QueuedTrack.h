#import <Foundation/Foundation.h>

#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

// The same track can be queued more than once, so each entry gets its own
// identity instead of borrowing the track's.
@interface QueuedTrack : NSObject

@property (nonatomic, readonly, copy) NSUUID *identifier;
@property (nonatomic, readonly) Track *track;

- (instancetype)initWithTrack:(Track *)track NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
