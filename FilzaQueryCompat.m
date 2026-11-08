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

static NSString *const FilzaGroupOverrideKey = @"FilzaWorseQueryAppGroupOverride";

NSString *FilzaWorseQueryGroupIdentifier(void)
{
    id group = [NSUserDefaults.standardUserDefaults stringForKey:FilzaGroupOverrideKey];
    if (![group isKindOfClass:NSString.class] || ![group length])
        group = [NSBundle.mainBundle objectForInfoDictionaryKey:@"FilzaWorseQueryAppGroup"];
    return [group isKindOfClass:NSString.class] ? [group stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

static BOOL FilzaGroupAccessible(NSString *group)
{
    return [group hasPrefix:@"group."] && group.length > 6 &&
        [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group] != nil;
}

BOOL FilzaWorseQueryReady(void) { return FilzaGroupAccessible(FilzaWorseQueryGroupIdentifier()); }

NSString *FilzaWorseQueryConfigurationStatus(void)
{
    NSString *group = FilzaWorseQueryGroupIdentifier();
    if (!group.length) return @"No App Group configured. Enter a dedicated group already provisioned for this signed app.";
    if (!FilzaGroupAccessible(group)) return [NSString stringWithFormat:
        @"App Group %@ is inaccessible. The app must be signed with its matching App Group entitlement and provisioning profile.", group];
    return [NSString stringWithFormat:@"App Group %@ is accessible. Target access is still unverified.", group];
}

NSString *FilzaWorseQueryConfigureGroup(NSString *identifier)
{
    NSString *group = [identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!group.length) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FilzaGroupOverrideKey];
        return nil;
    }
    if (!FilzaGroupAccessible(group)) return @"This group is not accessible to the signed app. Entering an ID cannot create an entitlement; provision the group and re-sign the app first.";
    [NSUserDefaults.standardUserDefaults setObject:group forKey:FilzaGroupOverrideKey];
    return nil;
}

NSString *FilzaWorseQueryErrorDescription(int64_t result)
{
    switch (result) {
        case -256: return FilzaWorseQueryReady() ? @"The requested App Group is inaccessible." : FilzaWorseQueryConfigurationStatus();
        case -258: return @"The group became unavailable during the request, or sandbox-extension consumption failed.";
        case -259: return @"A handle was returned, but reading the requested target was denied; the handle was released.";
        case -257: return @"Could not prepare the dedicated App Group Caches symlink.";
        case -255: return @"Invalid absolute target path.";
        case -254: return @"The target existence preflight failed.";
        case -1: return @"Required worse_query system symbols are unavailable.";
        case -2: return @"Could not create the worse_query request.";
        case -3: return @"ContainerManager rejected the worse_query request.";
        case -4: return @"No sandbox extension was issued.";
        default: return [NSString stringWithFormat:@"worse_query result: %lld", result];
    }
}

static BOOL FilzaTargetReadable(NSString *path)
{
    DIR *directory = opendir(path.fileSystemRepresentation);
    if (directory) {
        errno = 0;
        (void)readdir(directory);
        BOOL readable = errno == 0;
        closedir(directory);
        return readable;
    }
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) return NO;
    char byte;
    BOOL readable = read(fd, &byte, 1) >= 0;
    close(fd);
    return readable;
}

static void FilzaObserveQuery(NSString *path, int64_t result)
{
    NSString *status = result < 0 ? FilzaWorseQueryErrorDescription(result) :
        (FilzaTargetReadable(path) ? @"Read access observed; writes untested" : @"Handle received; read access not verified");
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
        NSString *group = group_identifier ? [NSString stringWithUTF8String:group_identifier] : FilzaWorseQueryGroupIdentifier();
        if (!FilzaGroupAccessible(group)) {
            FilzaObserveQuery(target, -256);
            return -256;
        }
        if (!create) {
            struct stat st;
            if (lstat(target.fileSystemRepresentation, &st) != 0) {
                FilzaObserveQuery(target, -254);
                return -254;
            }
        }

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
            // Map errors before recording so UI/logs use the same meanings.
            switch (result) {
                case -1: result = -258; break;
                case -2: result = -1; break;
                case -3: result = -2; break;
                case -4: result = -257; break;
                case -5: result = -3; break;
                case -6: result = -4; break;
                case -255: result = -254; break;
                default: break;
            }
            FilzaObserveQuery(target, result);
            return result;
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
        if (!root || max_inode < 1 || !FilzaWorseQueryReady()) return NULL;
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
    int64_t handle = bad_query(path, create, group_identifier, is_group);
    if (handle < 0) return handle;
    NSString *target = FilzaQueryPath(path);
    if (probe_leaf && probe_leaf[0]) {
        NSString *leaf = [NSString stringWithUTF8String:probe_leaf];
        if (!leaf.length || [leaf containsString:@"/"] || [leaf isEqualToString:@".."] || [leaf isEqualToString:@"."]) {
            worse_query_release(handle);
            return -255;
        }
        target = [target stringByAppendingPathComponent:leaf];
    }
    if (!FilzaTargetReadable(target)) {
        worse_query_release(handle);
        FilzaObserveQuery(target, -259);
        return -259;
    }
    FilzaObserveQuery(target, handle);
    return handle;
}

char *mond_bad_query_list(char *path, int64_t max_inode)
{
    return bad_query_list(path, max_inode);
}

void mond_bad_query_release(int64_t handle)
{
    bad_query_release(handle);
}
