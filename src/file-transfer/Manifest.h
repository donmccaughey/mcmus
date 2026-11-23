#import <Foundation/Foundation.h>


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

- (instancetype)initWithTrackMetadata:(NSArray<TrackMetadata *> *)metadata
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithCSV:(NSData *)csv error:(NSError **)error;

- (nullable TrackMetadata *)metadataForRelativePath:(NSString *)relativePath;

- (void)addOrReplaceTrack:(TrackMetadata *)trackMetadata;
- (void)addOrReplaceTracksFromArray:(NSArray<TrackMetadata *> *)metadata;
- (void)removeTrackWithRelativePath:(NSString *)relativePath;

// Both return this manifest's track metadata, sorted by path.
- (NSArray<TrackMetadata *> *)tracksMissingFrom:(Manifest *)other;
- (NSArray<TrackMetadata *> *)tracksChangedIn:(Manifest *)other;

@end


NS_ASSUME_NONNULL_END
