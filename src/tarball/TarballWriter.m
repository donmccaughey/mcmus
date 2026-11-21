#import "TarballWriter.h"

#import "FileSystem.h"
#import "TarballEntry.h"
#import "archive.h"
#import "archive_entry.h"


NSErrorDomain const TarballErrorDomain = @"TarballErrorDomain";

static const NSUInteger maxBufferLength = 64 * 1024;
static const NSUInteger readBufferLength = 1024 * 1024;


static NSError *tarball_error(TarballErrorCode code, NSString *description)
{
    return [NSError errorWithDomain:TarballErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}


static NSError *finished_error(void)
{
    return tarball_error(
        TarballErrorCodeFinished, @"The tarball is already complete.");
}


static NSError *archive_error(struct archive *_Nullable archive)
{
    const char *message = archive ? archive_error_string(archive) : NULL;
    return tarball_error(TarballErrorCodeArchiveFailed,
        message ? @(message) : @"The tar archive could not be written.");
}


static NSError *file_too_short_error(TarballEntry *entry)
{
    return tarball_error(TarballErrorCodeFileTooShort,
        [NSString stringWithFormat:@"%@ is shorter than %llu bytes.",
            entry.relativePath, entry.size]);
}


static la_ssize_t append_bytes(struct archive *archive, void *client_data,
    const void *buffer, size_t length)
{
    [(__bridge NSMutableData *)client_data appendBytes:buffer length:length];
    return (la_ssize_t)length;
}


static la_ssize_t count_bytes(struct archive *archive, void *client_data,
    const void *buffer, size_t length)
{
    *(unsigned long long *)client_data += length;
    return (la_ssize_t)length;
}


// A block size of zero turns off libarchive's output blocking, so each write
// reaches the callback at once and the tar file is not padded out to a
// multiple of the default 10240 byte block.
static struct archive *_Nullable new_archive(
    archive_write_callback *write, void *client_data)
{
    struct archive *archive = archive_write_new();
    if (!archive) return NULL;
    if (ARCHIVE_OK == archive_write_set_format_gnutar(archive)
        && ARCHIVE_OK == archive_write_set_bytes_per_block(archive, 0)
        && ARCHIVE_OK
            == archive_write_open(archive, client_data, NULL, write, NULL))
    {
        return archive;
    }
    archive_write_free(archive);
    return NULL;
}


// `archive_entry_copy_pathname()` stores the bytes untouched, where the UTF-8
// setters would convert them to decomposed form on Apple platforms.
static BOOL write_header(struct archive *archive, TarballEntry *entry)
{
    struct archive_entry *header = archive_entry_new();
    if (!header) return NO;
    archive_entry_copy_pathname(header, entry.relativePath.UTF8String);
    archive_entry_set_size(header, (la_int64_t)entry.size);
    archive_entry_set_mtime(header, entry.mtime, 0);
    archive_entry_set_filetype(header, AE_IFREG);
    archive_entry_set_perm(header, 0666);
    archive_entry_set_uid(header, 0);
    archive_entry_set_gid(header, 0);
    int status = archive_write_header(archive, header);
    archive_entry_free(header);
    return ARCHIVE_OK == status;
}


// Writes only the headers through the same code that writes the real tar
// file; libarchive fills in the data of each entry with zeros, so the bytes
// counted are the size of the real tar file.
static unsigned long long calculate_tarball_size(
    NSArray<TarballEntry *> *entries)
{
    unsigned long long size = 0;
    struct archive *archive = new_archive(count_bytes, &size);
    if (!archive) return 0;
    BOOL ok = YES;
    for (TarballEntry *entry in entries) {
        ok = ok && write_header(archive, entry);
    }
    ok = ok && ARCHIVE_OK == archive_write_close(archive);
    archive_write_free(archive);
    return ok ? size : 0;
}


@implementation TarballWriter {
    struct archive *_Nullable _archive;
    NSMutableData *_pending;
    NSUInteger _pendingOffset;
    NSMutableData *_readBuffer;
    NSUInteger _entryIndex;
    id<FileReader> _Nullable _reader;
    unsigned long long _entryRemaining;
    BOOL _isComplete;
    NSError *_Nullable _failure;
    BOOL _hasTarballSize;
    unsigned long long _tarballSize;
}


- (instancetype)initWithBaseDirectory:(NSURL *)baseDirectory
                              entries:(NSArray<TarballEntry *> *)entries
                           fileSystem:(id<FileSystem>)fileSystem;
{
    self = [super init];
    if (!self) return nil;

    _baseDirectory = baseDirectory;
    _entries = [entries copy];
    _fileSystem = fileSystem;
    _pending = [NSMutableData data];
    _readBuffer = [NSMutableData dataWithLength:readBufferLength];
    _archive = new_archive(append_bytes, (__bridge void *)_pending);
    if (!_archive) _failure = archive_error(NULL);

    return self;
}


- (void)dealloc;
{
    [_reader close];
    if (_archive) archive_write_free(_archive);
}


- (unsigned long long)tarballSize;
{
    if (!_hasTarballSize) {
        _tarballSize = calculate_tarball_size(_entries);
        _hasTarballSize = YES;
    }
    return _tarballSize;
}


- (nullable NSData *)nextBufferAndReturnError:(NSError **)error;
{
    if (self.pendingLength < maxBufferLength) [self discardReturnedBytes];
    while (!_failure && !_isComplete && self.pendingLength < maxBufferLength) {
        [self writeNextPiece];
    }
    if (_failure || 0 == self.pendingLength) {
        if (error) *error = _failure ?: finished_error();
        return nil;
    }
    return [self takePendingBuffer];
}


- (NSUInteger)pendingLength;
{
    return _pending.length - _pendingOffset;
}


// Returned bytes stay at the front of `_pending` until it needs refilling, so
// that a megabyte of file data is not shifted down once per 64 KB buffer.
- (void)discardReturnedBytes;
{
    [_pending replaceBytesInRange:NSMakeRange(0, _pendingOffset)
                        withBytes:NULL
                           length:0];
    _pendingOffset = 0;
}


- (NSData *)takePendingBuffer;
{
    NSUInteger length = MIN(maxBufferLength, self.pendingLength);
    NSData *buffer =
        [_pending subdataWithRange:NSMakeRange(_pendingOffset, length)];
    _pendingOffset += length;
    return buffer;
}


- (void)writeNextPiece;
{
    if (_reader) {
        [self writeFileData];
    } else if (_entryIndex < _entries.count) {
        [self startEntry];
    } else {
        [self finishArchive];
    }
}


- (void)startEntry;
{
    TarballEntry *entry = _entries[_entryIndex];
    NSURL *file = [_baseDirectory URLByAppendingPathComponent:entry.relativePath
                                                  isDirectory:NO];
    NSError *error;
    _reader = [_fileSystem openFileForReading:file error:&error];
    if (!_reader) {
        _failure = error;
    } else if (!write_header(_archive, entry)) {
        _failure = archive_error(_archive);
    }
    _entryRemaining = entry.size;
}


- (void)writeFileData;
{
    if (0 == _entryRemaining) {
        [self finishEntry];
        return;
    }
    size_t length = (size_t)MIN(readBufferLength, _entryRemaining);
    NSError *error;
    NSInteger count = [_reader readInto:_readBuffer.mutableBytes
                                 length:length
                                  error:&error];
    if (count < 0) {
        _failure = error;
    } else if (0 == count) {
        _failure = file_too_short_error(_entries[_entryIndex]);
    } else if (count
        != archive_write_data(_archive, _readBuffer.bytes, (size_t)count))
    {
        _failure = archive_error(_archive);
    }
    if (!_failure) _entryRemaining -= (unsigned long long)count;
}


- (void)finishEntry;
{
    [_reader close];
    _reader = nil;
    _entryIndex += 1;
    if (ARCHIVE_OK != archive_write_finish_entry(_archive)) {
        _failure = archive_error(_archive);
    }
}


- (void)finishArchive;
{
    if (ARCHIVE_OK != archive_write_close(_archive)) {
        _failure = archive_error(_archive);
    }
    _isComplete = YES;
}


@end
