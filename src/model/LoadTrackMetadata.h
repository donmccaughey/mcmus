#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "Track.h"
#import "TrackMetadata.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const LoadTrackMetadataErrorDomain;

typedef NS_ENUM(NSInteger, LoadTrackMetadataErrorCode) {
    LoadTrackMetadataErrorCodeHashFailed = 1,
};

NSArray<TrackMetadata *> *loadTrackMetadata(NSArray<Track *> *tracks,
    id<FileSystem> fileSystem, NSArray<NSError *> *_Nullable *_Nullable errors);

NS_ASSUME_NONNULL_END
