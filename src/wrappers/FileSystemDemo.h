#import <Foundation/Foundation.h>

#import "FileSystem.h"


NS_ASSUME_NONNULL_BEGIN


extern NSErrorDomain const FileSystemDemoErrorDomain;

typedef NS_ENUM(NSInteger, FileSystemDemoErrorCode) {
    FileSystemDemoErrorCodeNoDirectoryEntry = 1,
};


// Serves the directory tree in the demo data as the music root directory and
// forwards everything else to the wrapped file system.
@interface FileSystemDemo : NSObject <FileSystem>

@property (nonatomic, readonly, copy, nullable) NSURL *rootURL;

- (instancetype)initWithDemoData:(NSData *)demoData
                      fileSystem:(id<FileSystem>)fileSystem
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END
