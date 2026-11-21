#import "TarReading.h"

#import "archive.h"
#import "archive_entry.h"


static NSData *_Nullable read_entry_data(
    struct archive *tar, struct archive_entry *entry)
{
    NSMutableData *contents =
        [NSMutableData dataWithLength:(NSUInteger)archive_entry_size(entry)];
    la_ssize_t read =
        archive_read_data(tar, contents.mutableBytes, contents.length);
    return read == (la_ssize_t)contents.length ? contents : nil;
}


static NSArray<NSArray *> *_Nullable read_entries(struct archive *tar)
{
    NSMutableArray<NSArray *> *entries = [NSMutableArray array];
    struct archive_entry *entry;
    int status;
    while (ARCHIVE_OK == (status = archive_read_next_header(tar, &entry))) {
        NSString *path = @(archive_entry_pathname(entry));
        NSData *contents = read_entry_data(tar, entry);
        if (!contents) return nil;
        [entries addObject:@[path, contents]];
    }
    return ARCHIVE_EOF == status ? entries : nil;
}


NSArray<NSArray *> *_Nullable readTar(NSData *data)
{
    struct archive *tar = archive_read_new();
    archive_read_support_format_tar(tar);
    NSArray<NSArray *> *entries = nil;
    if (ARCHIVE_OK == archive_read_open_memory(tar, data.bytes, data.length)) {
        entries = read_entries(tar);
    }
    archive_read_free(tar);
    return entries;
}


static NSArray<NSNumber *> *_Nullable read_modification_times(
    struct archive *tar)
{
    NSMutableArray<NSNumber *> *mtimes = [NSMutableArray array];
    struct archive_entry *entry;
    int status;
    while (ARCHIVE_OK == (status = archive_read_next_header(tar, &entry))) {
        [mtimes addObject:@(archive_entry_mtime(entry))];
    }
    return ARCHIVE_EOF == status ? mtimes : nil;
}


NSArray<NSNumber *> *_Nullable readTarModificationTimes(NSData *data)
{
    struct archive *tar = archive_read_new();
    archive_read_support_format_tar(tar);
    NSArray<NSNumber *> *mtimes = nil;
    if (ARCHIVE_OK == archive_read_open_memory(tar, data.bytes, data.length)) {
        mtimes = read_modification_times(tar);
    }
    archive_read_free(tar);
    return mtimes;
}
