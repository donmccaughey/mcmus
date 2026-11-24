#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>
#import <net/if.h>

#import "FileSyncing.h"
#import "FileSystemReal.h"
#import "SyncTestOptions.h"


#define FILE_SHARES_CAPACITY 8

static const int usageExitStatus = 2;
static const NSUInteger findTimeoutSeconds = 5;

static struct file_share fileShares[FILE_SHARES_CAPACITY];
static FileSyncing *fileSyncing;


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
            stderr, "sync-test: %s\n%s\n",
            error.localizedDescription.UTF8String, SyncTestUsage.UTF8String
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
        stderr, "sync-test: %s: %s\n", directoryURL.path.UTF8String,
        error.localizedDescription.UTF8String
    );
    exit(EXIT_FAILURE);
}


static const char *interface_name(uint32_t interface_index, char *buffer)
{
    return if_indextoname(interface_index, buffer) ?: "unknown";
}


static void print_file_shares(struct file_share *file_shares, NSUInteger count)
{
    char name_buffer[IF_NAMESIZE];
    for (NSUInteger i = 0; i < count; ++i) {
        printf(
            "%lu: name=\"%s\" type=%s domain=%s interface=%u (%s)\n", i + 1,
            file_shares[i].service_name, file_shares[i].service_type,
            file_shares[i].domain, file_shares[i].interface_index,
            interface_name(file_shares[i].interface_index, name_buffer)
        );
    }
}


static void print_file_shares_and_exit(
    struct file_share *file_shares,
    NSUInteger count,
    DNSServiceErrorType error_code
)
{
    if (kDNSServiceErr_NoError != error_code) {
        fprintf(
            stderr, "sync-test: finding file shares failed with error %d\n",
            error_code
        );
        exit(EXIT_FAILURE);
    }

    if (count) {
        print_file_shares(file_shares, count);
    } else {
        printf("No file sharing servers found.\n");
    }
    exit(EXIT_SUCCESS);
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        SyncTestOptions *options = parse_options_or_exit();
        id<FileSystem> fileSystem = [FileSystemReal new];
        exit_unless_listable(options.musicDirectoryURL, fileSystem);
        exit_unless_listable(options.workingDirectoryURL, fileSystem);

        fileSyncing =
            [[FileSyncing alloc] initWithMusicDir:options.musicDirectoryURL
                                       workingDir:options.workingDirectoryURL
                                     manifestPath:options.manifestURL
                                       fileSystem:fileSystem];
        [fileSyncing findFileShares:fileShares
                       withCapacity:FILE_SHARES_CAPACITY
                        andCallback:print_file_shares_and_exit
                            onQueue:dispatch_get_main_queue()
                      withinSeconds:findTimeoutSeconds];
    }
    dispatch_main();
}


#endif
