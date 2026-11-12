#import "DemoMode.h"

#import "AudioDemo.h"
#import "FileSystemDemo.h"


// A missing or unreadable file is reported as invalid demo data when the
// music root directory is located.
static NSData *demo_data(void)
{
    NSURL *url = [NSBundle.mainBundle URLForResource:@"demo-data"
                                       withExtension:@"json"];
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    return data ?: [NSData data];
}


static NSURL *demo_track_url(void)
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSURL *resources = bundle.resourceURL ?: bundle.bundleURL;
    return [resources URLByAppendingPathComponent:@"demo-track.mp3"
                                      isDirectory:NO];
}


BOOL isDemoMode(void)
{
    return [NSProcessInfo.processInfo.arguments containsObject:@"--demo"];
}


id<FileSystem> demoFileSystemWrapping(id<FileSystem> fileSystem)
{
    return [[FileSystemDemo alloc] initWithDemoData:demo_data()
                                         fileSystem:fileSystem];
}


id<Audio> demoAudioWrapping(id<Audio> audio)
{
    return [[AudioDemo alloc] initWithDemoTrackURL:demo_track_url()
                                             audio:audio];
}
