#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>

#import "ClockReal.h"
#import "DNSReal.h"
#import "FileShareFinder.h"
#import "FileSyncing.h"
#import "FileSystemReal.h"
#import "Manifest.h"
#import "SyncTest.h"
#import "SyncTestOptions.h"


static const int usageExitStatus = 2;


static SyncTestOptions *parse_options_or_exit(void)
{
    NSURL *currentDirectoryURL =
        [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath
                   isDirectory:YES];
    NSError *error = nil;
    SyncTestOptions *options = [SyncTestOptions
        optionsWithArguments:NSProcessInfo.processInfo.arguments
         currentDirectoryURL:currentDirectoryURL
                       error:&error];
    if (!options) {
        fprintf(
            stderr,
            "sync-test: %s\n%s\n",
            error.localizedDescription.UTF8String,
            SyncTestUsage.UTF8String
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
        "sync-test: %s: %s\n",
        directoryURL.path.UTF8String,
        error.localizedDescription.UTF8String
    );
    exit(EXIT_FAILURE);
}


int main(int argc, const char *argv[])
{
    FileShareFinder *finder;
    FileSyncing *fileSyncing;
    SyncTest *syncTest;


    @autoreleasepool {
        SyncTestOptions *options = parse_options_or_exit();
        id<FileSystem> fileSystem = [FileSystemReal new];
        exit_unless_listable(options.musicDirectoryURL, fileSystem);
        exit_unless_listable(options.workingDirectoryURL, fileSystem);

        syncTest = [SyncTest new];
        id<DNS> dns = [DNSReal new];
        id<Clock> clock = [ClockReal new];
        fileSyncing =
            [[FileSyncing alloc] initWithMusicDir:options.musicDirectoryURL
                                       workingDir:options.workingDirectoryURL
                                     manifestPath:options.manifestURL
                                         delegate:syncTest
                                    delegateQueue:dispatch_get_main_queue()
                                       fileSystem:fileSystem
                                              dns:dns
                                            clock:clock];
        printf(
            "Local manifest contains %lu track(s)\n",
            (unsigned long)fileSyncing.localManifest.trackCount
        );
        syncTest.fileSyncing = fileSyncing;

        dispatch_queue_t serialQueue =
            dispatch_queue_create("sync-test", DISPATCH_QUEUE_SERIAL);
        finder =
            [[FileShareFinder alloc] initWithTimeout:3
                                         serialQueue:serialQueue
                                            delegate:syncTest
                                       delegateQueue:dispatch_get_main_queue()
                                                 dns:dns
                                               clock:clock];
        [finder start];
    }
    dispatch_main();
}


#endif
