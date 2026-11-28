#import <Foundation/Foundation.h>

#import "CSV.h"


@protocol FileSystem;

@class Manifest;
@class TrackMetadata;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncingState : NSObject

@property (nonatomic, readonly) Manifest *localManifest;
@property (nonatomic, readonly, nullable) Manifest *serverManifest;
@property (nonatomic, copy) NSArray<TrackMetadata *> *removedTracks;
@property (nonatomic, copy) NSArray<TrackMetadata *> *addedTracks;
@property (nonatomic, copy) NSArray<TrackMetadata *> *changedTracks;
@property (nonatomic, readonly)
    NSMutableDictionary<NSNumber *, CSVRecords> *tarballs;
@property (nonatomic, readonly) NSUInteger modifiedTrackCount;

- (instancetype)initWithLocalManifestPath:(NSURL *)localManifestPath
                            andFileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)updateWithServerManifest:(Manifest *)serverManifest;

@end


NS_ASSUME_NONNULL_END
