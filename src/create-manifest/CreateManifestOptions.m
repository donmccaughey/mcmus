#import "CreateManifestOptions.h"

#if TARGET_OS_OSX


NSString *const CreateManifestUsage =
    @"usage: create-manifest [--workdir=DIR] MUSIC_DIR";

static NSErrorDomain const CreateManifestOptionsErrorDomain =
    @"CreateManifestOptionsErrorDomain";
static NSString *const workdirOption = @"--workdir";
static NSString *const workdirOptionPrefix = @"--workdir=";


static NSError *options_error(NSString *description)
{
    return [NSError errorWithDomain:CreateManifestOptionsErrorDomain
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


@implementation CreateManifestOptions


- (instancetype)initWithMusicDirectoryURL:(NSURL *)musicDirectoryURL
                      workingDirectoryURL:(NSURL *)workingDirectoryURL;
{
    self = [super init];
    if (!self) return nil;

    _musicDirectoryURL = musicDirectoryURL;
    _workingDirectoryURL = workingDirectoryURL;

    return self;
}


+ (nullable instancetype)optionsWithArguments:(NSArray<NSString *> *)arguments
                          currentDirectoryURL:(NSURL *)currentDirectoryURL
                                        error:(NSError **)error;
{
    NSString *musicDir = nil;
    NSString *workingDir = nil;
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
    return [[self alloc]
        initWithMusicDirectoryURL:directory_url(musicDir, currentDirectoryURL)
              workingDirectoryURL:workingDirectoryURL];
}


@end


#endif
