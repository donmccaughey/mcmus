#import "Manifest.h"

#import "CSV.h"
#import "TrackMetadata.h"


static NSString *path_relative_to_music_library(
    Track *track, NSURL *musicLibraryDir)
{
    NSString *prefix = [musicLibraryDir.path stringByAppendingString:@"/"];
    if (![track.path hasPrefix:prefix]) return track.path;
    return [track.path substringFromIndex:prefix.length];
}


static NSDictionary<NSString *, TrackMetadata *> *metadata_by_relative_path(
    NSArray<TrackMetadata *> *metadata, NSURL *musicLibraryDir)
{
    NSMutableDictionary<NSString *, TrackMetadata *> *metadataByRelativePath =
        [NSMutableDictionary dictionaryWithCapacity:metadata.count];
    for (TrackMetadata *trackMetadata in metadata) {
        NSString *relativePath = path_relative_to_music_library(
            trackMetadata.track, musicLibraryDir);
        metadataByRelativePath[relativePath] = trackMetadata;
    }
    return metadataByRelativePath;
}


// Orders paths by their UTF-8 bytes, so that the order does not depend on
// the locale or on Unicode normalization.
static NSComparisonResult compare_records_by_path(
    NSArray<NSString *> *first, NSArray<NSString *> *second, void *context)
{
    int order = strcmp(first[0].UTF8String, second[0].UTF8String);
    if (order < 0) return NSOrderedAscending;
    if (order > 0) return NSOrderedDescending;
    return NSOrderedSame;
}


static NSArray<NSArray<NSString *> *> *manifest_records(
    NSDictionary<NSString *, TrackMetadata *> *metadataByRelativePath)
{
    NSMutableArray<NSArray<NSString *> *> *records =
        [NSMutableArray arrayWithCapacity:metadataByRelativePath.count + 1];
    [metadataByRelativePath enumerateKeysAndObjectsUsingBlock:^(
        NSString *relativePath, TrackMetadata *trackMetadata, BOOL *stop) {
        [records addObject:@[
            relativePath,
            [NSString stringWithFormat:@"%llu", trackMetadata.size],
            [NSString stringWithFormat:@"%lu", trackMetadata.fileHash],
        ]];
    }];
    [records sortUsingFunction:compare_records_by_path context:NULL];
    [records insertObject:@[@"path", @"size", @"hash"] atIndex:0];
    return records;
}


@implementation Manifest {
    NSDictionary<NSString *, TrackMetadata *> *_metadataByRelativePath;
}


- (instancetype)initWithTrackMetadata:(NSArray<TrackMetadata *> *)metadata
                musicLibraryDirectory:(NSURL *)musicLibraryDir;
{
    self = [super init];
    if (!self) return nil;

    _musicLibraryDirectory = musicLibraryDir;
    _metadataByRelativePath =
        metadata_by_relative_path(metadata, musicLibraryDir);
    _csv = generateCSV(manifest_records(_metadataByRelativePath));

    return self;
}


- (NSUInteger)trackCount;
{
    return _metadataByRelativePath.count;
}


- (nullable TrackMetadata *)metadataForRelativePath:(NSString *)relativePath;
{
    return _metadataByRelativePath[relativePath];
}


@end
