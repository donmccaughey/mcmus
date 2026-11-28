#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>

#import "CreateManifestOptions.h"
#import "FileSystemReal.h"
#import "LoadMusicLibrary.h"
#import "LoadTrackMetadata.h"
#import "Manifest.h"
#import "MusicLibrary.h"


static const int usageExitStatus = 2;
static NSString *const manifestName = @"manifest.csv";

static BOOL isProgressLineOpen;
static NSUInteger printedTracksLoaded = NSNotFound;


static CreateManifestOptions *parse_options_or_exit(void)
{
    NSURL *currentDirectoryURL =
        [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath
                   isDirectory:YES];
    NSError *error = nil;
    CreateManifestOptions *options = [CreateManifestOptions
        optionsWithArguments:NSProcessInfo.processInfo.arguments
         currentDirectoryURL:currentDirectoryURL
                       error:&error];
    if (!options) {
        fprintf(
            stderr,
            "create-manifest: %s\n%s\n",
            error.localizedDescription.UTF8String,
            CreateManifestUsage.UTF8String
        );
        exit(usageExitStatus);
    }
    return options;
}


static void exit_unless_listable(NSURL *directoryURL, id<FileSystem> fileSystem)
{
    NSError *error = nil;
    if ([fileSystem listDirectory:directoryURL error:&error]) return;

    fprintf(
        stderr,
        "create-manifest: %s: %s\n",
        directoryURL.path.UTF8String,
        error.localizedDescription.UTF8String
    );
    exit(EXIT_FAILURE);
}


// A hash failure carries only the track's path, so the path is printed for
// every error that has one.
static void print_errors(NSArray<NSError *> *errors)
{
    for (NSError *error in errors) {
        NSString *path = error.userInfo[NSFilePathErrorKey];
        if (path) {
            fprintf(
                stderr,
                "create-manifest: %s: %s\n",
                path.UTF8String,
                error.localizedDescription.UTF8String
            );
        } else {
            fprintf(
                stderr,
                "create-manifest: %s\n",
                error.localizedDescription.UTF8String
            );
        }
    }
}


// The final count is printed after loading as well as from the progress
// callback, which would repeat it when the total is a multiple of the
// callback's interval.
static void print_progress(NSUInteger tracksLoaded, NSUInteger totalTracks)
{
    if (tracksLoaded == printedTracksLoaded) return;
    printedTracksLoaded = tracksLoaded;

    // A pipe or file gets one line per update, since a carriage return would
    // leave every progress update in a single unterminated line.
    BOOL overwritesProgress = isatty(STDOUT_FILENO);
    printf(
        overwritesProgress ? "\rLoading track metadata… %lu of %lu"
                           : "Loading track metadata… %lu of %lu\n",
        tracksLoaded,
        totalTracks
    );
    fflush(stdout);
    isProgressLineOpen = overwritesProgress;
}


static void end_progress_line(void)
{
    if (!isProgressLineOpen) return;
    printf("\n");
    isProgressLineOpen = NO;
}


static NSArray<Track *> *load_tracks(
    NSURL *musicDirectoryURL, id<FileSystem> fileSystem
)
{
    LoadResult *result = loadMusicLibrary(musicDirectoryURL, fileSystem);
    print_errors(result.errors);
    return [result.library getTracks];
}


static NSArray<TrackMetadata *> *load_metadata_printing_progress(
    NSArray<Track *> *tracks,
    NSURL *musicDirectoryURL,
    id<FileSystem> fileSystem
)
{
    NSArray<NSError *> *errors = nil;
    NSArray<TrackMetadata *> *metadata = loadTrackMetadata(
        tracks,
        musicDirectoryURL,
        fileSystem,
        ^(NSUInteger tracksLoaded, NSUInteger totalTracks) {
            print_progress(tracksLoaded, totalTracks);
        },
        &errors
    );
    print_progress(tracks.count, tracks.count);
    end_progress_line();
    print_errors(errors);
    return metadata;
}


static void write_manifest_or_exit(
    Manifest *manifest, NSURL *workingDirectoryURL, id<FileSystem> fileSystem
)
{
    NSURL *manifestURL =
        [workingDirectoryURL URLByAppendingPathComponent:manifestName
                                             isDirectory:NO];
    NSError *error = nil;
    if (![fileSystem writeData:manifest.csv toFile:manifestURL error:&error]) {
        fprintf(
            stderr,
            "create-manifest: %s: %s\n",
            manifestURL.path.UTF8String,
            error.localizedDescription.UTF8String
        );
        exit(EXIT_FAILURE);
    }
    printf(
        "Wrote %lu track(s) to %s\n",
        manifest.trackCount,
        manifestURL.path.UTF8String
    );
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        CreateManifestOptions *options = parse_options_or_exit();
        id<FileSystem> fileSystem = [FileSystemReal new];
        exit_unless_listable(options.musicDirectoryURL, fileSystem);
        exit_unless_listable(options.workingDirectoryURL, fileSystem);

        NSArray<Track *> *tracks =
            load_tracks(options.musicDirectoryURL, fileSystem);
        NSArray<TrackMetadata *> *metadata = load_metadata_printing_progress(
            tracks, options.musicDirectoryURL, fileSystem
        );
        Manifest *manifest = [[Manifest alloc] initWithTrackMetadata:metadata];
        write_manifest_or_exit(
            manifest, options.workingDirectoryURL, fileSystem
        );
    }
    return EXIT_SUCCESS;
}


#endif
