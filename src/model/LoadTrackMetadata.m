#import "LoadTrackMetadata.h"

#import <assert.h>

#import "xxhash.h"

NSErrorDomain const LoadTrackMetadataErrorDomain =
    @"LoadTrackMetadataErrorDomain";

static const NSUInteger progressInterval = 100;

static_assert(sizeof(XXH64_hash_t) == sizeof(NSUInteger),
    "TrackMetadata stores the XXH3-64 digest in an NSUInteger");

static NSError *hashFailed(NSURL *trackURL)
{
    return [NSError errorWithDomain:LoadTrackMetadataErrorDomain
                               code:LoadTrackMetadataErrorCodeHashFailed
                           userInfo:@{NSFilePathErrorKey: trackURL.path}];
}

static BOOL hashFile(NSURL *trackURL, id<FileSystem> fileSystem,
    XXH3_state_t *state, NSUInteger *fileHash, NSError **error)
{
    if (XXH_OK != XXH3_64bits_reset(state)) {
        *error = hashFailed(trackURL);
        return NO;
    }
    __block XXH_errorcode updated = XXH_OK;
    BOOL read = [fileSystem
        readFile:trackURL chunks:^(const void *bytes, size_t length) {
            if (XXH_OK == updated)
                updated = XXH3_64bits_update(state, bytes, length);
        }
           error:error];
    if (!read) return NO;
    if (XXH_OK != updated) {
        *error = hashFailed(trackURL);
        return NO;
    }
    *fileHash = XXH3_64bits_digest(state);
    return YES;
}

// A track whose hash cannot be gathered still gets metadata, with the
// "not gathered" hash of zero. The state is NULL when it could not be
// allocated, which fails every track's hash.
static NSUInteger readTrackHash(NSURL *trackURL, id<FileSystem> fileSystem,
    XXH3_state_t *_Nullable state, NSMutableArray<NSError *> *errors)
{
    if (!state) {
        [errors addObject:hashFailed(trackURL)];
        return 0;
    }
    NSUInteger fileHash = 0;
    NSError *error;
    if (!hashFile(trackURL, fileSystem, state, &fileHash, &error)) {
        [errors addObject:error];
        return 0;
    }
    return fileHash;
}

static TrackMetadata *_Nullable loadOneTrackMetadata(Track *track,
    id<FileSystem> fileSystem, XXH3_state_t *_Nullable state,
    NSMutableArray<NSError *> *errors)
{
    NSURL *trackURL = track.url;
    unsigned long long size = 0;
    NSError *error;
    if (![fileSystem getSize:&size ofFile:trackURL error:&error]) {
        [errors addObject:error];
        return nil;
    }
    NSUInteger fileHash = readTrackHash(trackURL, fileSystem, state, errors);
    return [[TrackMetadata alloc] initWithTrack:track size:size
                                       fileHash:fileHash];
}

NSArray<TrackMetadata *> *loadTrackMetadata(NSArray<Track *> *tracks,
    id<FileSystem> fileSystem, LoadTrackMetadataProgress _Nullable progress,
    NSArray<NSError *> *_Nullable *_Nullable errors)
{
    NSMutableArray<TrackMetadata *> *metadata =
        [NSMutableArray arrayWithCapacity:tracks.count];
    NSMutableArray<NSError *> *loadErrors = [NSMutableArray array];
    XXH3_state_t *state = XXH3_createState();
    NSUInteger tracksLoaded = 0;
    for (Track *track in tracks) {
        TrackMetadata *trackMetadata =
            loadOneTrackMetadata(track, fileSystem, state, loadErrors);
        if (trackMetadata) [metadata addObject:trackMetadata];
        ++tracksLoaded;
        if (progress && 0 == tracksLoaded % progressInterval) {
            progress(tracksLoaded, tracks.count);
        }
    }
    XXH3_freeState(state);
    if (errors) *errors = loadErrors;
    return metadata;
}
