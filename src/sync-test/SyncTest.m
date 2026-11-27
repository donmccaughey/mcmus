#import "SyncTest.h"

#import <net/if.h>

#import "FileShare.h"
#import "FileShareSelection.h"
#import "FileSyncing.h"
#import "Manifest.h"


static void printFileShares(NSArray<FileShare *> *fileShares);
static FileShare *promptForFileShareOrExit(NSArray<FileShare *> *fileShares);


@implementation SyncTest


#pragma BrowserDelegate


- (void)didFindFileShares:(NSArray<FileShare *> *)fileShares;
{
    if (!fileShares.count) {
        printf("No file sharing servers found.\n");
        exit(EXIT_SUCCESS);
    }

    printFileShares(fileShares);
    FileShare *fileShare = fileShares.count == 1
        ? fileShares.firstObject
        : promptForFileShareOrExit(fileShares);
    [_fileSyncing syncWithFileShare:fileShare];
}


- (void)didFailToBrowseWithError:(NSError *)error;
{
    fprintf(
        stderr,
        "sync-test: finding file shares failed with error %li\n",
        error.code
    );
    exit(EXIT_FAILURE);
}


#pragma FileSyncingDelegate


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;
{
    printf("%lu track(s) synced.\n", modifiedTrackCount);
    exit(EXIT_SUCCESS);
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    willSyncWithModifiedTrackCount:(NSUInteger)modifiedTrackCount;
{
    if (modifiedTrackCount) {
        printf("Will sync %lu track(s).\n", modifiedTrackCount);
    } else {
        printf("Music library is up-to-date.\n");
    }
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                  toURL:(NSURL *)url;
{
    printf("File sharing URL: %s.\n", url.description.UTF8String);
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToResolveFileShare:(FileShare *)fileShare
                    withError:(NSError *)error;
{
    fprintf(
        stderr,
        "sync-test: finding file share failed with error %li\n",
        error.code
    );
    exit(EXIT_FAILURE);
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
     didGetManifest:(Manifest *)manifest;
{
    printf(
        "Server manifest contains %lu track(s)\n",
        (unsigned long)manifest.trackCount
    );
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToGetManifestWithError:(NSError *)error;
{
    fprintf(
        stderr,
        "sync-test: getting manifest failed with error %s %li\n",
        error.domain.UTF8String,
        error.code
    );
    exit(EXIT_FAILURE);
}


@end


static const char *interfaceName(NSUInteger interfaceIndex, char *buffer)
{
    return if_indextoname((unsigned)interfaceIndex, buffer) ?: "unknown";
}


static void printFileShares(NSArray<FileShare *> *fileShares)
{
    char nameBuffer[IF_NAMESIZE];
    for (NSUInteger i = 0; i < fileShares.count; ++i) {
        FileShare *fileShare = [fileShares objectAtIndex:i];
        printf(
            "%lu: name=\"%s\" type=%s domain=%s interface=%u (%s)\n",
            i + 1,
            fileShare.serviceName.UTF8String,
            fileShare.serviceType.UTF8String,
            fileShare.domain.UTF8String,
            (unsigned)fileShare.interfaceIndex,
            interfaceName(fileShare.interfaceIndex, nameBuffer)
        );
    }
}


// Returns an empty string for a line that is not UTF-8, so that only end of
// input reads as nil.
static NSString *_Nullable readLine(void)
{
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length = getline(&line, &capacity, stdin);
    NSString *string =
        length < 0 ? nil : [NSString stringWithUTF8String:line] ?: @"";
    free(line);
    return string;
}


// Blocks the main queue while waiting for an answer. Nothing else is due
// there: FileSyncing works on its own queue and is idle between finding and
// resolving.
static FileShare *promptForFileShareOrExit(NSArray<FileShare *> *fileShares)
{
    for (;;) {
        printf(
            "Select a file share (1-%lu), or q to cancel: ", fileShares.count
        );
        fflush(stdout);

        NSString *answer = readLine();
        BOOL isEndOfInput = !answer;
        FileShareSelection selection =
            parse_file_share_selection(answer, fileShares.count);
        switch (selection.kind) {
        case FileShareSelectionKindSelected:
            return [fileShares objectAtIndex:selection.index];
        case FileShareSelectionKindCancelled:
            if (isEndOfInput) printf("\n");
            printf("Cancelled.\n");
            exit(EXIT_SUCCESS);
        case FileShareSelectionKindInvalid: break;
        }
    }
}
