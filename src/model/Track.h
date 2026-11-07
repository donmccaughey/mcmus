#import <Foundation/Foundation.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

@interface Track : NSObject <FolderChild>

@property (nonatomic, readonly, copy) NSString *trackName;
@property (nonatomic, readonly, copy) NSString *albumName;
@property (nonatomic, readonly, copy) NSString *artistName;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) NSURL *url;

@property (class, nonatomic, readonly) NSString *noAlbum;
@property (class, nonatomic, readonly) NSString *noArtist;

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithDisplayName:(NSString *)displayName
                               pathExtension:(NSString *)pathExtension
                                        path:(NSString *)path
                                  folderName:(nullable NSString *)folderName
                            parentFolderName:(nullable NSString *)parentFolderName;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
