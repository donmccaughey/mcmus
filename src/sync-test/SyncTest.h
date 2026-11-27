#import <Foundation/Foundation.h>

#import "FileShareFinderDelegate.h"
#import "FileSyncingDelegate.h"


@class FileSyncing;


NS_ASSUME_NONNULL_BEGIN


@interface SyncTest : NSObject <FileShareFinderDelegate, FileSyncingDelegate>

@property (nonatomic) FileSyncing *fileSyncing;

@end


NS_ASSUME_NONNULL_END
