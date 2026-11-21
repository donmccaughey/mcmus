#import <Foundation/Foundation.h>


@class TrackMetadata;


NS_ASSUME_NONNULL_BEGIN


@interface Manifest : NSObject

@property (nonatomic, readonly) NSUInteger trackCount;
@property (nonatomic, readonly) NSData *csv;

- (instancetype)initWithTrackMetadata:(NSArray<TrackMetadata *> *)metadata
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable TrackMetadata *)metadataForRelativePath:(NSString *)relativePath;

@end


NS_ASSUME_NONNULL_END
