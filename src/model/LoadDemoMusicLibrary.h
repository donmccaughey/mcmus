#import <Foundation/Foundation.h>

#import "LoadResult.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const LoadDemoErrorDomain;

typedef NS_ENUM(NSInteger, LoadDemoErrorCode) {
    LoadDemoErrorCodeNoDirectoryEntry = 1,
};

LoadResult *loadDemoMusicLibrary(NSData *demoData, NSString *trackPath);

NS_ASSUME_NONNULL_END
