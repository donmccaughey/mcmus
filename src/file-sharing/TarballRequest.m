#import "TarballRequest.h"

#if TARGET_OS_OSX


#import "CSV.h"
#import "HTTPRequestParser.h"
#import "Manifest.h"
#import "TarballEntry.h"
#import "TrackMetadata.h"


NSErrorDomain const TarballRequestErrorDomain = @"TarballRequestErrorDomain";

static NSString *const tarballCSVContentType = @"text/csv;charset=UTF-8";
static const unsigned long long maxRequestedSize = 100ULL * 1024 * 1024;


static NSError *tarball_request_error(
    TarballRequestErrorCode code, NSString *description
)
{
    return [NSError errorWithDomain:TarballRequestErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}


// The parser reads a body of exactly the length the header gives, so a
// length that does not match the body cannot be seen here: a shorter body
// times out and the bytes after a longer one are read as the next request.
static BOOL has_content(HTTPRequest *request)
{
    return request.hasContentLength && request.body.length;
}


static NSArray<NSString *> *_Nullable requested_paths(NSData *tarballCSV)
{
    NSArray<NSArray<NSString *> *> *records = parseCSV(tarballCSV, NULL);
    if (records.count < 2) return nil;
    if (![records.firstObject isEqual:@[@"path"]]) return nil;

    NSMutableArray<NSString *> *paths =
        [NSMutableArray arrayWithCapacity:records.count - 1];
    for (NSUInteger i = 1; i < records.count; ++i) {
        [paths addObject:records[i][0]];
    }
    return paths;
}


static NSArray<TarballEntry *> *_Nullable entries_for_paths(
    NSArray<NSString *> *paths, Manifest *manifest, time_t snapshotTime
)
{
    NSMutableArray<TarballEntry *> *entries =
        [NSMutableArray arrayWithCapacity:paths.count];
    for (NSString *path in paths) {
        TrackMetadata *metadata = [manifest metadataForRelativePath:path];
        if (!metadata) return nil;
        [entries
            addObject:[[TarballEntry alloc] initWithRelativePath:path
                                                            size:metadata.size
                                                           mtime:snapshotTime]];
    }
    return entries;
}


// A single track is sent whatever its size, since it cannot be asked for in
// smaller pieces.
static BOOL is_too_big(NSArray<TarballEntry *> *entries)
{
    unsigned long long requestedSize = 0;
    for (TarballEntry *entry in entries)
        requestedSize += entry.size;
    return requestedSize > maxRequestedSize && entries.count > 1;
}


NSArray<TarballEntry *> *_Nullable parseTarballRequest(
    HTTPRequest *request,
    Manifest *manifest,
    time_t snapshotTime,
    NSError **error
)
{
    NSError *failure = nil;
    NSArray<TarballEntry *> *entries = nil;
    NSArray<NSString *> *paths = nil;

    if (!has_content(request)) {
        failure = tarball_request_error(
            TarballRequestErrorCodeInvalidContentLength,
            @"Invalid content length"
        );
    } else if (![request.contentType isEqual:tarballCSVContentType]) {
        failure = tarball_request_error(
            TarballRequestErrorCodeInvalidContentType, @"Invalid content type"
        );
    } else if (!(paths = requested_paths(request.body))) {
        failure = tarball_request_error(
            TarballRequestErrorCodeInvalidCSV, @"Invalid CSV"
        );
    } else if (!(entries = entries_for_paths(paths, manifest, snapshotTime))) {
        failure = tarball_request_error(
            TarballRequestErrorCodeUnknownTrack, @"Unknown track"
        );
    } else if (is_too_big(entries)) {
        failure = tarball_request_error(
            TarballRequestErrorCodeTarballTooBig, @"Tarball too big"
        );
    }

    if (failure && error) *error = failure;
    return failure ? nil : entries;
}


#endif
