#import "SyncTest.h"

#import <net/if.h>

#import "FileShare.h"
#import "FileSyncing.h"


static void printFileShares(NSArray<FileShare *> *fileShares);


@implementation SyncTest


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFindFileShares:(NSArray<FileShare *> *)fileShares;
{
    if (fileShares.count) {
        printFileShares(fileShares);
        [fileSyncing resolveFileShare:fileShares.firstObject withTimeout:3];
    } else {
        printf("No file sharing servers found.\n");
        exit(EXIT_SUCCESS);
    }
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToFindFileSharesWithError:(NSError *)error;
{
    fprintf(
        stderr,
        "sync-test: finding file shares failed with error %li\n",
        error.code
    );
    exit(EXIT_FAILURE);
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                  toURL:(NSURL *)url;
{
    printf("File sharing URL: %s.\n", url.description.UTF8String);
    exit(EXIT_SUCCESS);
}


- (void)fileSyncing:(FileSyncing *)fileSyncing
    didFailToResolveFileShare:(FileShare *)fileShare
                    withError:(NSError *)error;
{
    fprintf(
        stderr,
        "sync-test: finding getting URL failed with error %li\n",
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
