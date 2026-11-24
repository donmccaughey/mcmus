#import "ShareTestStatus.h"

#if TARGET_OS_OSX


#import "FileSharing.h"


static NSString *creating_snapshot_text(FileSharing *fileSharing)
{
    NSUInteger totalTracks = fileSharing.metadataTotalTracks;
    if (!totalTracks) return @"Creating snapshot…";

    NSUInteger percent = fileSharing.metadataTracksLoaded * 100 / totalTracks;
    return [NSString stringWithFormat:@"Creating snapshot… (%lu%%)", percent];
}


NSString *share_test_status_text(FileSharing *fileSharing)
{
    switch (fileSharing.state) {
    case FileSharingStateStarting: return creating_snapshot_text(fileSharing);
    case FileSharingStateStopping: return @"Removing snapshot…";
    case FileSharingStateOff:
    case FileSharingStateSharing: break;
    }
    if (fileSharing.error) {
        return
            [NSString stringWithFormat:@"Sharing failed: %@",
                                       fileSharing.error.localizedDescription];
    }
    if (!fileSharing.isSharing) return @"Not sharing.";

    NSString *deviceName = fileSharing.connectedDeviceName;
    if (!deviceName) return @"No device connected.";
    return [NSString stringWithFormat:@"Connected to %@.", deviceName];
}


#endif
