#import "MusicLibraryStore.h"

#import "LoadMusicLibrary.h"

static LoadResult *failedResult(NSArray<NSError *> *errors) {
    return [[LoadResult alloc] initWithLibrary:[[MusicLibrary alloc] init] errors:errors];
}

static LoadResult *loadLibrary(MusicRootDirectory *_Nullable musicRootDirectory,
                               NSError *_Nullable locateError,
                               id<FileSystem> fileSystem) {
    if (!musicRootDirectory) {
        return failedResult(locateError ? @[locateError] : @[]);
    }
    return loadMusicLibrary(musicRootDirectory.url, LoadOptionsNone, fileSystem);
}

static dispatch_queue_t loadQueue(void) {
    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
}

@interface MusicLibraryStore ()

@property (nonatomic, readwrite, nullable) MusicRootDirectory *musicRootDirectory;

@end

@implementation MusicLibraryStore {
    id<FileSystem> _fileSystem;
    id<Preferences> _preferences;
    // A superseded load still walks to completion since loadMusicLibrary does
    // not check for cancellation, so its result is dropped on arrival instead.
    NSInteger _loadGeneration;
}

+ (NSNotificationName)libraryDidChangeNotification {
    return @"MusicLibraryStoreLibraryDidChange";
}

+ (NSNotificationName)musicRootDirectoryDidChangeNotification {
    return @"MusicLibraryStoreMusicRootDirectoryDidChange";
}

- (instancetype)initWithFileSystem:(id<FileSystem>)fileSystem
                       preferences:(id<Preferences>)preferences;
{
    self = [super init];
    if ( ! self) return nil;

    _library = [[MusicLibrary alloc] init];
    _loadErrors = @[];
    _fileSystem = fileSystem;
    _preferences = preferences;

    return self;
}

- (instancetype)init;
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (BOOL)loadDidFail {
    return _loadErrors.count > 0;
}

- (void)apply:(LoadResult *)result {
    _library = result.library;
    _loadErrors = result.errors;
    [[NSNotificationCenter defaultCenter] postNotificationName:MusicLibraryStore.libraryDidChangeNotification
                                                        object:self];
}

- (void)loadInBackground {
    [self loadInBackgroundWithCompletion:nil];
}

- (void)loadInBackgroundWithCompletion:(nullable void (^)(void))completion {
    NSInteger generation = [self nextLoadGeneration];
    id<FileSystem> fileSystem = _fileSystem;
    id<Preferences> preferences = _preferences;
    dispatch_async(loadQueue(), ^{
        NSError *locateError;
        MusicRootDirectory *musicRootDirectory = [MusicRootDirectory locateWithFileSystem:fileSystem
                                                                              preferences:preferences
                                                                                    error:&locateError];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.musicRootDirectory = musicRootDirectory;
        });
        LoadResult *result = loadLibrary(musicRootDirectory, locateError, fileSystem);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishLoad:result generation:generation completion:completion];
        });
    });
}

#if TARGET_OS_OSX
- (void)changeMusicRootDirectoryTo:(NSURL *)url {
    [self changeMusicRootDirectoryTo:url completion:nil];
}

- (void)changeMusicRootDirectoryTo:(NSURL *)url completion:(nullable void (^)(void))completion {
    if ([url.path isEqualToString:_musicRootDirectory.url.path]) {
        if (completion) {
            completion();
        }
        return;
    }
    [_musicRootDirectory stopAccessingWithFileSystem:_fileSystem];
    MusicRootDirectory *musicRootDirectory = [MusicRootDirectory choose:url
                                                             fileSystem:_fileSystem
                                                            preferences:_preferences];
    self.musicRootDirectory = musicRootDirectory;
    NSInteger generation = [self nextLoadGeneration];
    id<FileSystem> fileSystem = _fileSystem;
    dispatch_async(loadQueue(), ^{
        LoadResult *result = loadMusicLibrary(musicRootDirectory.url, LoadOptionsNone, fileSystem);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishLoad:result generation:generation completion:completion];
        });
    });
}
#endif

- (NSInteger)nextLoadGeneration {
    _loadGeneration += 1;
    return _loadGeneration;
}

- (void)setMusicRootDirectory:(nullable MusicRootDirectory *)musicRootDirectory {
    _musicRootDirectory = musicRootDirectory;
    [[NSNotificationCenter defaultCenter] postNotificationName:MusicLibraryStore.musicRootDirectoryDidChangeNotification
                                                        object:self];
}

- (void)finishLoad:(LoadResult *)result generation:(NSInteger)generation completion:(nullable void (^)(void))completion {
    if (generation == _loadGeneration) {
        [self apply:result];
    }
    if (completion) {
        completion();
    }
}

@end
