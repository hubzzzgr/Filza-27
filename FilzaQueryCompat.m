#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#import "FilzaAccessStatus.h"
#include "compat/bad_query.h"
#import "ThirdParty/worse_query/worse_query.h"
#import "ThirdParty/worse_query/pathleak.h"

static NSMutableDictionary<NSString *, NSString *> *FilzaAccessObservations(void)
{
    static NSMutableDictionary *observations;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ observations = [NSMutableDictionary new]; });
    return observations;
}

NSDictionary<NSString *, NSString *> *FilzaWorseQueryObservedAccess(void)
{
    NSMutableDictionary *observations = FilzaAccessObservations();
    @synchronized (observations) { return observations.copy; }
}

static void FilzaObserveQuery(NSString *path, int64_t result)
{
    NSString *status = nil;
    if (result < 0) {
        status = [NSString stringWithFormat:@"Grant failed (%lld)", result];
    } else {
        // Observe actual readability; never infer it from an extension handle.
        DIR *directory = opendir(path.fileSystemRepresentation);
        BOOL readable = NO;
        if (directory) {
            errno = 0;
            (void)readdir(directory);
            readable = errno == 0;
            closedir(directory);
        } else {
            int fd = open(path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
            if (fd >= 0) {
                char byte;
                readable = read(fd, &byte, 1) >= 0;
                close(fd);
            }
        }
        status = readable ? @"Read access observed; writes untested" : @"Handle received; read access not verified";
    }
    NSMutableDictionary *observations = FilzaAccessObservations();
    @synchronized (observations) {
        if (observations.count >= 64 && !observations[path]) [observations removeObjectForKey:observations.allKeys.firstObject];
        observations[path] = status;
    }
}

static NSString *FilzaQueryPath(const char *path)
{
    if (!path || path[0] != '/') return nil;
    NSString *value = [NSFileManager.defaultManager
        stringWithFileSystemRepresentation:path length:strlen(path)];
    // fsgetpath and callers use both spellings. Do not resolve inaccessible paths.
    if ([value hasPrefix:@"/private/var/"] || [value isEqualToString:@"/private/var"])
        value = [value substringFromIndex:8];
    return value.stringByStandardizingPath;
}

int64_t bad_query(char *path, bool create, char *group_identifier, bool is_group)
{
    @autoreleasepool {
        NSString *target = FilzaQueryPath(path);
        if (!target) return -255;
        if (!create) {
            struct stat st;
            if (lstat(target.fileSystemRepresentation, &st) != 0) return -254;
        }
        NSString *group = group_identifier ? [NSString stringWithUTF8String:group_identifier]
            : [NSBundle.mainBundle objectForInfoDictionaryKey:@"FilzaWorseQueryAppGroup"];
        if (![group isKindOfClass:NSString.class] || ![group hasPrefix:@"group."])
            return -256;

        // All Filza/3105/Mond requests share Library/Caches in the same group.
        // Serialize the complete upstream symlink/query/cleanup transaction.
        static NSObject *queryLock;
        static dispatch_once_t once;
        dispatch_once(&once, ^{ queryLock = [NSObject new]; });
        @synchronized (queryLock) {
            BOOL appGroupTarget = [target isEqualToString:@"/var/mobile/Containers/Shared/AppGroup"] ||
                [target hasPrefix:@"/var/mobile/Containers/Shared/AppGroup/"];
            BOOL altFlags = is_group || (appGroupTarget &&
                NSProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26);
            int64_t result = worse_query(target, group, altFlags, create);
            FilzaObserveQuery(target, result);
            // Preserve legacy diagnostics while keeping new prerequisites distinct.
            switch (result) {
                case -1: return -256; // group unavailable or extension consumption failed
                case -2: return -1;   // symbols unavailable
                case -3: return -2;   // query creation failed
                case -4: return -257; // group Caches symlink failed
                case -5: return -3;   // query rejected
                case -6: return -4;   // token not issued
                case -255: return -254; // target preflight failed
                default: return result;
            }
        }
    }
}

void bad_query_release(int64_t handle)
{
    worse_query_release(handle);
}

char *bad_query_list(char *path, int64_t max_inode)
{
    @autoreleasepool {
        NSString *root = FilzaQueryPath(path);
        if (!root || max_inode < 1) return NULL;
        NSArray<NSString *> *paths = pathleak(root, (uint64_t)max_inode);
        if (!paths) return NULL;
        // Existing ObjC and Swift callers expect newline-separated, freeable data.
        NSString *listing = paths.count
            ? [[paths componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"] : @"";
        return strdup(listing.UTF8String);
    }
}

int64_t mond_bad_query(char *path, bool create, char *group_identifier,
                       bool is_group, char *probe_leaf)
{
    // Upstream's probe only opened a diagnostic FD and did not affect its result.
    // Actual readability/writeability checks remain the responsibility of callers.
    (void)probe_leaf;
    return bad_query(path, create, group_identifier, is_group);
}

char *mond_bad_query_list(char *path, int64_t max_inode)
{
    return bad_query_list(path, max_inode);
}

void mond_bad_query_release(int64_t handle)
{
    bad_query_release(handle);
}
