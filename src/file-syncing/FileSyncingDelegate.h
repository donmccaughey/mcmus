#import <Foundation/Foundation.h>


@class FileShare;
@class FileSyncing;
@class Manifest;


@protocol FileSyncingDelegate <NSObject>

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    willSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                  toURL:(NSURL *)url;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToResolveFileShare:(FileShare *)fileShare
                    withError:(NSError *)error;

- (void)fileSyncing:(FileSyncing *)fileSyncing
     didGetManifest:(Manifest *)manifest;

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToGetManifestWithError:(NSError *)error;

@end
