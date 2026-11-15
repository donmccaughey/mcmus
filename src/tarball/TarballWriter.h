#import <Foundation/Foundation.h>

@class TarballEntry;
@protocol FileSystem;


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const TarballErrorDomain;

typedef NS_ENUM(NSInteger, TarballErrorCode) {
    TarballErrorCodeFinished = 1,
    TarballErrorCodeArchiveFailed,
    TarballErrorCodeFileTooShort,
};


// Generates a GNU format tar file a buffer at a time. A writer makes one tar
// file; once a call to `nextBufferAndReturnError:` fails, every later call
// fails with the same error.
@interface TarballWriter : NSObject

@property (nonatomic, readonly) NSURL *baseDirectory;
@property (nonatomic, readonly, copy) NSArray<TarballEntry *> *entries;
@property (nonatomic, readonly) id<FileSystem> fileSystem;

// Zero if the size cannot be calculated; a tar file is never empty.
@property (nonatomic, readonly) unsigned long long tarballSize;

- (instancetype)initWithBaseDirectory:(NSURL *)baseDirectory
                              entries:(NSArray<TarballEntry *> *)entries
                           fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable NSData *)nextBufferAndReturnError:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
