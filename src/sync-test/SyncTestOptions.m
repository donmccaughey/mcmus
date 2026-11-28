#import "SyncTestOptions.h"

#if TARGET_OS_OSX


NSString *const SyncTestUsage =
    @"usage: sync-test [--workdir=DIR] [--manifest=MANIFEST_PATH] "
    @"[--share-name=SHARE_NAME] MUSIC_DIR";

static NSErrorDomain const SyncTestOptionsErrorDomain =
    @"SyncTestOptionsErrorDomain";
static NSString *const workdirOption = @"--workdir";
static NSString *const workdirOptionPrefix = @"--workdir=";
static NSString *const manifestOption = @"--manifest";
static NSString *const manifestOptionPrefix = @"--manifest=";
static NSString *const shareNameOption = @"--share-name";
static NSString *const shareNameOptionPrefix = @"--share-name=";
static NSString *const defaultManifestName = @"manifest.csv";


static NSError *options_error(NSString *description)
{
    return [NSError errorWithDomain:SyncTestOptionsErrorDomain
                               code:1
                           userInfo:@{
                               NSLocalizedDescriptionKey: description,
                           }];
}


static NSURL *directory_url(NSString *path, NSURL *currentDirectoryURL)
{
    return [NSURL fileURLWithPath:path
                      isDirectory:YES
                    relativeToURL:currentDirectoryURL]
        .absoluteURL;
}


static NSURL *file_url(NSString *path, NSURL *currentDirectoryURL)
{
    return [NSURL fileURLWithPath:path
                      isDirectory:NO
                    relativeToURL:currentDirectoryURL]
        .absoluteURL;
}


@implementation SyncTestOptions


- (instancetype)initWithMusicDirectoryURL:(NSURL *)musicDirectoryURL
                      workingDirectoryURL:(NSURL *)workingDirectoryURL
                              manifestURL:(NSURL *)manifestURL
                                shareName:(nullable NSString *)shareName;
{
    self = [super init];
    if (!self) return nil;

    _musicDirectoryURL = musicDirectoryURL;
    _workingDirectoryURL = workingDirectoryURL;
    _manifestURL = manifestURL;
    _shareName = [shareName copy];

    return self;
}


+ (nullable instancetype)optionsWithArguments:(NSArray<NSString *> *)arguments
                          currentDirectoryURL:(NSURL *)currentDirectoryURL
                                        error:(NSError **)error;
{
    NSString *musicDir = nil;
    NSString *workingDir = nil;
    NSString *manifestPath = nil;
    NSString *shareName = nil;
    NSError *parseError = nil;

    for (NSUInteger i = 1; i < arguments.count; ++i) {
        NSString *argument = arguments[i];
        if ([argument hasPrefix:workdirOptionPrefix]) {
            workingDir =
                [argument substringFromIndex:workdirOptionPrefix.length];
            if (!workingDir.length) {
                parseError = options_error(@"--workdir requires a DIR value");
            }
        } else if ([argument isEqual:workdirOption]) {
            parseError = options_error(@"--workdir requires a DIR value");
        } else if ([argument hasPrefix:manifestOptionPrefix]) {
            manifestPath =
                [argument substringFromIndex:manifestOptionPrefix.length];
            if (!manifestPath.length) {
                parseError =
                    options_error(@"--manifest requires a MANIFEST_PATH value");
            }
        } else if ([argument isEqual:manifestOption]) {
            parseError =
                options_error(@"--manifest requires a MANIFEST_PATH value");
        } else if ([argument hasPrefix:shareNameOptionPrefix]) {
            shareName =
                [argument substringFromIndex:shareNameOptionPrefix.length];
            if (!shareName.length) {
                parseError =
                    options_error(@"--share-name requires a SHARE_NAME value");
            }
        } else if ([argument isEqual:shareNameOption]) {
            parseError =
                options_error(@"--share-name requires a SHARE_NAME value");
        } else if ([argument hasPrefix:@"--"]) {
            parseError = options_error([@"unknown option "
                stringByAppendingString:argument]);
        } else if (musicDir) {
            parseError = options_error([@"unexpected argument "
                stringByAppendingString:argument]);
        } else {
            musicDir = argument;
        }
        if (parseError) break;
    }
    if (!parseError && !musicDir.length) {
        parseError = options_error(@"missing MUSIC_DIR");
    }
    if (parseError) {
        if (error) *error = parseError;
        return nil;
    }

    NSURL *workingDirectoryURL = workingDir
        ? directory_url(workingDir, currentDirectoryURL)
        : currentDirectoryURL;
    NSURL *manifestURL = manifestPath
        ? file_url(manifestPath, currentDirectoryURL)
        : [workingDirectoryURL URLByAppendingPathComponent:defaultManifestName
                                               isDirectory:NO];
    return [[self alloc]
        initWithMusicDirectoryURL:directory_url(musicDir, currentDirectoryURL)
              workingDirectoryURL:workingDirectoryURL
                      manifestURL:manifestURL
                        shareName:shareName];
}


@end


#endif
