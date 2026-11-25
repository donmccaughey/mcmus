#import "SyncTest.h"


@implementation SyncTest

- (void)fileSyncing:(FileSyncing *)fileSyncing
    didResolveFileShare:(FileShare *)fileShare
                withURL:(NSURL *)url;
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
