#import "Manifest.h"

#import "CSV.h"
#import "TrackMetadata.h"


NSErrorDomain const ManifestErrorDomain = @"ManifestErrorDomain";


// Orders paths by their UTF-8 bytes, so that the order does not depend on
// the locale or on Unicode normalization.
static NSComparisonResult compare_paths_by_bytes(
    NSString *first, NSString *second, void *context)
{
    int order = strcmp(first.UTF8String, second.UTF8String);
    if (order < 0) return NSOrderedAscending;
    if (order > 0) return NSOrderedDescending;
    return NSOrderedSame;
}


static NSArray<NSString *> *sorted_relative_paths(
    NSDictionary<NSString *, TrackMetadata *> *metadataByRelativePath)
{
    return [metadataByRelativePath.allKeys
        sortedArrayUsingFunction:compare_paths_by_bytes
                         context:NULL];
}


static NSArray<NSArray<NSString *> *> *manifest_records(
    NSDictionary<NSString *, TrackMetadata *> *metadataByRelativePath)
{
    NSMutableArray<NSArray<NSString *> *> *records =
        [NSMutableArray arrayWithCapacity:metadataByRelativePath.count + 1];
    [records addObject:@[@"path", @"size", @"hash"]];
    for (NSString *relativePath in sorted_relative_paths(
             metadataByRelativePath))
    {
        TrackMetadata *trackMetadata = metadataByRelativePath[relativePath];
        [records addObject:@[
            relativePath,
            [NSString stringWithFormat:@"%llu", trackMetadata.size],
            [NSString stringWithFormat:@"%lu", trackMetadata.fileHash],
        ]];
    }
    return records;
}


static NSError *manifest_error(ManifestErrorCode code, NSString *description)
{
    return [NSError errorWithDomain:ManifestErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}


// strtoull() alone would accept a sign, leading white space and trailing
// text.
static BOOL parse_decimal_uint64(NSString *text, unsigned long long *value)
{
    if (!text.length) return NO;
    for (NSUInteger i = 0; i < text.length; ++i) {
        unichar character = [text characterAtIndex:i];
        if (character < '0' || character > '9') return NO;
    }

    errno = 0;
    *value = strtoull(text.UTF8String, NULL, 10);
    return errno != ERANGE;
}


static TrackMetadata *_Nullable metadata_for_record(
    NSArray<NSString *> *record, NSUInteger recordNumber, NSError **error)
{
    unsigned long long size = 0;
    if (!parse_decimal_uint64(record[1], &size)) {
        if (error) {
            *error = manifest_error(ManifestErrorCodeInvalidSize,
                [NSString stringWithFormat:@"Invalid size in record %lu",
                    (unsigned long)recordNumber]);
        }
        return nil;
    }

    unsigned long long fileHash = 0;
    if (!parse_decimal_uint64(record[2], &fileHash)) {
        if (error) {
            *error = manifest_error(ManifestErrorCodeInvalidHash,
                [NSString stringWithFormat:@"Invalid hash in record %lu",
                    (unsigned long)recordNumber]);
        }
        return nil;
    }

    return [[TrackMetadata alloc] initWithRelativePath:record[0]
                                                  size:size
                                              fileHash:(NSUInteger)fileHash];
}


static NSArray<TrackMetadata *> *_Nullable metadata_for_csv(
    NSData *csv, NSError **error)
{
    NSArray<NSArray<NSString *> *> *records = parseCSV(csv, error);
    if (!records) return nil;

    if (![records.firstObject isEqual:@[@"path", @"size", @"hash"]]) {
        if (error) {
            *error = manifest_error(
                ManifestErrorCodeInvalidHeader, @"Invalid manifest header");
        }
        return nil;
    }

    NSMutableArray<TrackMetadata *> *metadata =
        [NSMutableArray arrayWithCapacity:records.count - 1];
    for (NSUInteger i = 1; i < records.count; ++i) {
        TrackMetadata *trackMetadata =
            metadata_for_record(records[i], i + 1, error);
        if (!trackMetadata) return nil;
        [metadata addObject:trackMetadata];
    }
    return metadata;
}


@implementation Manifest {
    NSMutableDictionary<NSString *, TrackMetadata *> *_metadataByRelativePath;
    NSData *_Nullable _cachedCSV;
}


- (instancetype)initWithTrackMetadata:(NSArray<TrackMetadata *> *)metadata;
{
    self = [super init];
    if (!self) return nil;

    _metadataByRelativePath =
        [NSMutableDictionary dictionaryWithCapacity:metadata.count];
    [self addOrReplaceTracksFromArray:metadata];

    return self;
}


- (nullable instancetype)initWithCSV:(NSData *)csv error:(NSError **)error;
{
    NSArray<TrackMetadata *> *metadata = metadata_for_csv(csv, error);
    if (!metadata) return nil;

    return [self initWithTrackMetadata:metadata];
}


- (NSUInteger)trackCount;
{
    return _metadataByRelativePath.count;
}


- (nullable TrackMetadata *)metadataForRelativePath:(NSString *)relativePath;
{
    return _metadataByRelativePath[relativePath];
}


// The file sharing server reads the CSV on every manifest request, while
// file syncing adds tracks one at a time, so the CSV is generated on demand
// and kept until the next change.
- (NSData *)csv;
{
    if (!_cachedCSV) {
        _cachedCSV = generateCSV(manifest_records(_metadataByRelativePath));
    }
    return _cachedCSV;
}


- (void)addOrReplaceTrack:(TrackMetadata *)trackMetadata;
{
    _metadataByRelativePath[trackMetadata.relativePath] = trackMetadata;
    _cachedCSV = nil;
}


- (void)addOrReplaceTracksFromArray:(NSArray<TrackMetadata *> *)metadata;
{
    for (TrackMetadata *trackMetadata in metadata) {
        [self addOrReplaceTrack:trackMetadata];
    }
}


- (void)removeTrackWithRelativePath:(NSString *)relativePath;
{
    [_metadataByRelativePath removeObjectForKey:relativePath];
    _cachedCSV = nil;
}


- (NSArray<TrackMetadata *> *)tracksMissingFrom:(Manifest *)other;
{
    NSMutableArray<TrackMetadata *> *missing = [NSMutableArray array];
    for (NSString *relativePath in sorted_relative_paths(
             _metadataByRelativePath))
    {
        if (![other metadataForRelativePath:relativePath]) {
            [missing addObject:_metadataByRelativePath[relativePath]];
        }
    }
    return missing;
}


- (NSArray<TrackMetadata *> *)tracksChangedIn:(Manifest *)other;
{
    NSMutableArray<TrackMetadata *> *changed = [NSMutableArray array];
    for (NSString *relativePath in sorted_relative_paths(
             _metadataByRelativePath))
    {
        TrackMetadata *trackMetadata = _metadataByRelativePath[relativePath];
        TrackMetadata *otherMetadata =
            [other metadataForRelativePath:relativePath];
        if (otherMetadata && otherMetadata.fileHash != trackMetadata.fileHash) {
            [changed addObject:trackMetadata];
        }
    }
    return changed;
}


@end
