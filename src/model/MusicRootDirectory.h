#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "Preferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface MusicRootDirectory : NSObject

@property (nonatomic, readonly, copy) NSURL *url;
@property (nonatomic, readonly) BOOL isSecurityScoped;

- (instancetype)initWithURL:(NSURL *)url isSecurityScoped:(BOOL)isSecurityScoped NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

+ (nullable MusicRootDirectory *)locateWithFileSystem:(id<FileSystem>)fileSystem
                                          preferences:(id<Preferences>)preferences
                                                error:(NSError **)error;

#if TARGET_OS_OSX
+ (MusicRootDirectory *)choose:(NSURL *)url
                    fileSystem:(id<FileSystem>)fileSystem
                   preferences:(id<Preferences>)preferences;
- (void)stopAccessingWithFileSystem:(id<FileSystem>)fileSystem;
#endif

@end

NS_ASSUME_NONNULL_END
