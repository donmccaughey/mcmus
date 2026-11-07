#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileSystemItemInfo : NSObject

@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly) BOOL isRegularFile;
@property (nonatomic, readonly) BOOL isPackage;
@property (nonatomic, readonly, copy, nullable) NSString *localizedName;

- (instancetype)initWithIsDirectory:(BOOL)isDirectory
                      isRegularFile:(BOOL)isRegularFile
                          isPackage:(BOOL)isPackage
                      localizedName:(nullable NSString *)localizedName NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface ResolvedBookmark : NSObject

@property (nonatomic, readonly, copy) NSURL *url;
@property (nonatomic, readonly) BOOL isStale;

- (instancetype)initWithURL:(NSURL *)url isStale:(BOOL)isStale NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@protocol FileSystem <NSObject>

- (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error;
- (nullable NSURL *)getApplicationSupportDirectoryURLAndReturnError:(NSError **)error;
- (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error;
- (BOOL)excludeFromBackup:(NSURL *)url error:(NSError **)error;
- (nullable NSArray<NSURL *> *)listDirectory:(NSURL *)directory error:(NSError **)error;
- (nullable FileSystemItemInfo *)getFileInfo:(NSURL *)url error:(NSError **)error;

// Security-scoped bookmarks are a macOS App Sandbox feature; iOS
// keeps its music inside the app container and needs none of this.
#if TARGET_OS_OSX
- (nullable NSData *)makeSecurityScopedBookmarkFor:(NSURL *)url error:(NSError **)error;
- (nullable ResolvedBookmark *)resolveSecurityScopedBookmark:(NSData *)bookmark error:(NSError **)error;
- (BOOL)startAccessing:(NSURL *)url;
- (void)stopAccessing:(NSURL *)url;
#endif

@end

NS_ASSUME_NONNULL_END
