#import <Foundation/Foundation.h>

#import "FileSystem.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const FileSystemFakeErrorDomain;

typedef NS_ENUM(NSInteger, FileSystemFakeErrorCode) {
    FileSystemFakeErrorCodeOperationFailed = 1,
};

typedef NS_ENUM(NSInteger, FileSystemFakeKind) {
    FileSystemFakeKindDirectory,
    FileSystemFakeKindFile,
    FileSystemFakeKindPackage,
    // Neither a directory nor a regular file, such as a symlink or socket.
    FileSystemFakeKindOther,
};

@interface FileSystemFakeEntry : NSObject

@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) FileSystemFakeKind kind;
@property (nonatomic, readonly, copy, nullable) NSString *localizedName;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, readonly, copy, nullable) NSData *contents;

- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName
                        size:(unsigned long long)size
                    contents:(nullable NSData *)contents
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName
                        size:(unsigned long long)size;
- (instancetype)initWithPath:(NSString *)path
                        kind:(FileSystemFakeKind)kind
               localizedName:(nullable NSString *)localizedName;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface FileSystemFake : NSObject <FileSystem>

@property (nonatomic, copy) NSArray<FileSystemFakeEntry *> *entries;
@property (nonatomic, copy) NSSet<NSString *> *unlistableDirectories;
@property (nonatomic, copy) NSSet<NSString *> *unreadableEntries;
@property (nonatomic, copy) NSSet<NSString *> *unsizeableFiles;
@property (nonatomic, copy) NSSet<NSString *> *unreadableFiles;
@property (nonatomic, copy) NSSet<NSString *> *uncreatableDirectories;
@property (nonatomic, copy) NSSet<NSString *> *unbookmarkablePaths;
@property (nonatomic, copy) NSSet<NSString *> *unresolvableBookmarks;
@property (nonatomic, copy) NSSet<NSString *> *staleBookmarks;
@property (nonatomic, copy) NSSet<NSString *> *inaccessiblePaths;
@property (nonatomic, copy, nullable) NSURL *applicationSupportDirectoryURL;
@property (nonatomic, copy, nullable) NSURL *musicDirectoryURL;
@property (nonatomic, readonly, copy) NSArray<NSString *> *bookmarked;
@property (nonatomic, readonly, copy) NSArray<NSString *> *started;
@property (nonatomic, readonly, copy) NSArray<NSString *> *stopped;
@property (nonatomic, readonly, copy) NSArray<NSString *> *clonedSources;
@property (nonatomic, readonly, copy) NSArray<NSString *> *clonedDestinations;
@property (nonatomic, readonly, copy)
    NSDictionary<NSString *, NSData *> *writtenFiles;
@property (nonatomic, nullable) NSError *writeDataToFileError;
@property (nonatomic, nullable) NSError *removeItemAtURLError;
@property (nonatomic, nullable) NSError *cloneFileToFileError;

- (void)addPath:(NSString *)path;
- (void)addPath:(NSString *)path kind:(FileSystemFakeKind)kind;
- (void)addPath:(NSString *)path
             kind:(FileSystemFakeKind)kind
    localizedName:(nullable NSString *)localizedName;
- (void)addPath:(NSString *)path size:(unsigned long long)size;
- (void)addPath:(NSString *)path contents:(NSData *)contents;

+ (NSData *)bookmarkForPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
