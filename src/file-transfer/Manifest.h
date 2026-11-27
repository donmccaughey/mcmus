#import <Foundation/Foundation.h>


@protocol FileSystem;
@class TrackMetadata;


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const ManifestErrorDomain;

typedef NS_ENUM(NSInteger, ManifestErrorCode) {
    ManifestErrorCodeInvalidHeader = 1,
    ManifestErrorCodeInvalidSize,
    ManifestErrorCodeInvalidHash,
};


@interface Manifest : NSObject

@property (nonatomic, readonly) NSUInteger trackCount;
@property (nonatomic, readonly) NSData *csv;

+ (nullable instancetype)newWithCSVPath:(NSURL *)csvPath
                             fileSystem:(id<FileSystem>)fileSystem
                                  error:(NSError **)error;

- (instancetype)initWithTrackMetadata:(NSArray<TrackMetadata *> *)metadata
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init;

- (nullable instancetype)initWithCSV:(NSData *)csv error:(NSError **)error;

- (nullable TrackMetadata *)metadataForRelativePath:(NSString *)relativePath;

- (void)addOrReplaceTrack:(TrackMetadata *)trackMetadata;
- (void)addOrReplaceTracksFromArray:(NSArray<TrackMetadata *> *)metadata;
- (void)removeTrackWithRelativePath:(NSString *)relativePath;

// Both return this manifest's track metadata, sorted by path.
- (NSArray<TrackMetadata *> *)tracksMissingFrom:(Manifest *)other;
- (NSArray<TrackMetadata *> *)tracksChangedFrom:(Manifest *)other;

@end


NS_ASSUME_NONNULL_END
