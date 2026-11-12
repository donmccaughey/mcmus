#import <Foundation/Foundation.h>

#import "FileSystem.h"
#import "LoadResult.h"
#import "MusicLibrary.h"
#import "MusicRootDirectory.h"
#import "Preferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface MusicLibraryStore : NSObject

@property (class, nonatomic, readonly)
    NSNotificationName libraryDidChangeNotification;
// Separate from the library, so a root change alone leaves the files
// panel, and the macOS outline's expansion, untouched.
@property (class, nonatomic, readonly)
    NSNotificationName musicRootDirectoryDidChangeNotification;

@property (nonatomic, readonly) MusicLibrary *library;
@property (nonatomic, readonly, copy) NSArray<NSError *> *loadErrors;
@property (nonatomic, readonly) BOOL loadDidFail;
@property (nonatomic, readonly, nullable)
    MusicRootDirectory *musicRootDirectory;

- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem
                       preferences:(id<Preferences>)preferences
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)apply:(LoadResult *)result;

- (void)loadInBackground;
// The completion runs on the main queue once the load has finished,
// whether or not a later load superseded it.
- (void)loadInBackgroundWithCompletion:(nullable void (^)(void))completion;

#if TARGET_OS_OSX
- (void)changeMusicRootDirectoryTo:(NSURL *)url;
- (void)changeMusicRootDirectoryTo:(NSURL *)url
                        completion:(nullable void (^)(void))completion;
#endif

@end

NS_ASSUME_NONNULL_END
