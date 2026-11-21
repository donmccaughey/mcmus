#import <TargetConditionals.h>
#if TARGET_OS_OSX


#import <Foundation/Foundation.h>

#import "FileSharing.h"
#import "FileSystemReal.h"
#import "ShareTestOptions.h"
#import "ShareTestStatus.h"


static const int usageExitStatus = 2;

static id changeObserver;
static dispatch_source_t interruptSource;
static BOOL isInterrupted;
static BOOL isProgressLineOpen;


static ShareTestOptions *parse_options_or_exit(void)
{
    NSURL *currentDirectoryURL =
        [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath
                   isDirectory:YES];
    NSError *error = nil;
    ShareTestOptions *options = [ShareTestOptions
        optionsWithArguments:NSProcessInfo.processInfo.arguments
         currentDirectoryURL:currentDirectoryURL
                       error:&error];
    if (!options) {
        fprintf(stderr, "share-test: %s\n%s\n",
            error.localizedDescription.UTF8String, ShareTestUsage.UTF8String);
        exit(usageExitStatus);
    }
    return options;
}


static void exit_unless_listable(NSURL *directoryURL)
{
    NSError *error = nil;
    if ([[FileSystemReal new] listDirectory:directoryURL error:&error]) return;

    fprintf(stderr, "share-test: %s: %s\n", directoryURL.path.UTF8String,
        error.localizedDescription.UTF8String);
    exit(EXIT_FAILURE);
}


// A pipe or file gets one line per status, since a carriage return would
// leave every progress update in a single unterminated line.
static BOOL overwrites_progress(FileSharing *fileSharing)
{
    return fileSharing.state == FileSharingStateStarting
        && isatty(STDOUT_FILENO);
}


static void print_progress(NSString *status)
{
    printf("\r%s", status.UTF8String);
    fflush(stdout);
    isProgressLineOpen = YES;
}


static void end_progress_line(void)
{
    if (!isProgressLineOpen) return;
    printf("\n");
    isProgressLineOpen = NO;
}


static void print_changes(FileSharing *fileSharing)
{
    static uint16_t printedPort;
    static NSString *printedStatus;

    uint16_t port = fileSharing.port;
    if (port && port != printedPort) {
        end_progress_line();
        printf("Listening on port %d\n", port);
    }
    printedPort = port;

    NSString *status = share_test_status_text(fileSharing);
    if ([status isEqual:printedStatus]) return;
    printedStatus = status;
    if (overwrites_progress(fileSharing)) {
        print_progress(status);
        return;
    }
    end_progress_line();
    fprintf(fileSharing.error ? stderr : stdout, "%s\n", status.UTF8String);
}


static void print_changes_as_they_happen(FileSharing *fileSharing)
{
    changeObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:FileSharing.didChangeNotification
                    object:fileSharing
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    print_changes(fileSharing);
                }];
}


static void stop_and_exit(FileSharing *fileSharing)
{
    [fileSharing stopWithCompletion:^{
        exit(fileSharing.error ? EXIT_FAILURE : EXIT_SUCCESS);
    }];
}


// The file sharing object ignores stop while it is starting, so an interrupt
// that arrives then is acted on when the start completes.
static void stop_on_interrupt(FileSharing *fileSharing)
{
    signal(SIGINT, SIG_IGN);
    interruptSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(interruptSource, ^{
        isInterrupted = YES;
        if (fileSharing.isSharing) stop_and_exit(fileSharing);
    });
    dispatch_resume(interruptSource);
}


static void start(FileSharing *fileSharing)
{
    [fileSharing startWithCompletion:^{
        if (!fileSharing.isSharing) exit(EXIT_FAILURE);
        if (isInterrupted) stop_and_exit(fileSharing);
    }];
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        ShareTestOptions *options = parse_options_or_exit();
        exit_unless_listable(options.musicDirectoryURL);
        exit_unless_listable(options.workingDirectoryURL);

        // A pipe would otherwise hold status lines back until the buffer fills.
        setlinebuf(stdout);

        FileSharing *fileSharing = [[FileSharing alloc]
            initWithMusicRootDirectoryURL:options.musicDirectoryURL
                      workingDirectoryURL:options.workingDirectoryURL];
        print_changes_as_they_happen(fileSharing);
        stop_on_interrupt(fileSharing);
        start(fileSharing);
    }
    dispatch_main();
}


#endif
