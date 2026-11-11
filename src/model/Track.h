#import <Foundation/Foundation.h>

#import "FolderChild.h"

NS_ASSUME_NONNULL_BEGIN

@interface Track : NSObject <FolderChild>

@property (nonatomic, readonly, copy) NSString *trackName;
@property (nonatomic, readonly, copy) NSString *albumName;
@property (nonatomic, readonly, copy) NSString *artistName;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) unsigned long long size;

@property (class, nonatomic, readonly) NSString *noAlbum;
@property (class, nonatomic, readonly) NSString *noArtist;

+ (BOOL)isMusicFileExtension:(NSString *)pathExtension;

- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path
                             size:(unsigned long long)size NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTrackName:(NSString *)trackName
                        albumName:(NSString *)albumName
                       artistName:(NSString *)artistName
                             path:(NSString *)path;
- (nullable instancetype)initWithDisplayName:(NSString *)displayName
                               pathExtension:(NSString *)pathExtension
                                        path:(NSString *)path
                                  folderName:(nullable NSString *)folderName
                            parentFolderName:(nullable NSString *)parentFolderName
                                        size:(unsigned long long)size;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
