#import <Foundation/Foundation.h>

#import "Track.h"

NS_ASSUME_NONNULL_BEGIN

@interface TrackMetadata : NSObject

@property (nonatomic, readonly) Track *track;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, readonly) NSUInteger fileHash;

- (instancetype)initWithTrack:(Track *)track
                         size:(unsigned long long)size
                     fileHash:(NSUInteger)fileHash NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
