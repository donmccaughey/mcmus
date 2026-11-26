#import <Foundation/Foundation.h>


@protocol FileSystem;

@class Manifest;


NS_ASSUME_NONNULL_BEGIN


@interface FileSyncingState : NSObject

@property (nonatomic, readonly) Manifest *localManifest;
@property (nonatomic, readonly, nullable) Manifest *serverManifest;

- (instancetype)initWithLocalManifestPath:(NSURL *)localManifestPath
                            andFileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)updateWithServerManifest:(Manifest *)serverManifest;

@end


NS_ASSUME_NONNULL_END
