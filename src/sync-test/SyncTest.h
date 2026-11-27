#import <Foundation/Foundation.h>

#import "BrowserDelegate.h"
#import "FileSyncingDelegate.h"


@class FileSyncing;


NS_ASSUME_NONNULL_BEGIN


@interface SyncTest : NSObject <BrowserDelegate, FileSyncingDelegate>

@property (nonatomic) FileSyncing *fileSyncing;

@end


NS_ASSUME_NONNULL_END
