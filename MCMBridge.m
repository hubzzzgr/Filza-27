#import "MCMBridge.h"
#import "FilzaAccessStatus.h"
#import "compat/bad_query.h"
#import <dirent.h>
#import <stdlib.h>
#import <dispatch/dispatch.h>
#import <sys/xattr.h>

static NSString *QueryRoot(uint64_t kind)
{
    switch (kind) {
        case 2: return @"/var/mobile/Containers/Data/Application";
        case 4: return @"/var/mobile/Containers/Data/PluginKitPlugin";
        case 7: return @"/var/mobile/Containers/Shared/AppGroup";
        case 10: return @"/var/mobile/Containers/Data/InternalDaemon";
        case 12: return @"/var/containers/Data/System";
        case 13: return @"/var/containers/Shared/SystemGroup";
        default: return nil;
    }
}

BOOL MCMBridgeAvailable(void)
{
    return FilzaWorseQueryReady();
}

static NSMutableDictionary *QueryMaps(void)
{
    static NSMutableDictionary *maps;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ maps = [NSMutableDictionary new]; });
    return maps;
}

static NSDictionary<NSString *, NSString *> *QueryContainers(uint64_t kind)
{
    if (!MCMBridgeAvailable()) return @{};
    NSMutableDictionary *maps = QueryMaps();
    @synchronized (maps) {
        if (maps[@(kind)]) return maps[@(kind)];
        NSString *root = QueryRoot(kind);
        if (!root) return @{};
        NSMutableDictionary *found = [NSMutableDictionary new];
        char *raw = bad_query_list((char *)root.fileSystemRepresentation, 2000000);
        if (!raw) return @{}; // Allow a later retry after a failed scan.
        NSString *listing = [NSString stringWithUTF8String:raw] ?: @"";
        free(raw);
        for (NSString *path in [listing componentsSeparatedByString:@"\n"]) {
            if (!path.length) continue;
            int64_t lease = bad_query((char *)path.fileSystemRepresentation, true, NULL, false);
            if (lease < 0) continue;
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:
                [path stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
            NSString *identifier = metadata[@"MCMMetadataIdentifier"];
            if (![identifier isKindOfClass:NSString.class] || !identifier.length) {
                char value[1024] = {0};
                ssize_t count = getxattr(path.fileSystemRepresentation,
                    "com.apple.containermanager.identifier", value, sizeof(value)-1, 0, 0);
                identifier = count > 0 ? [NSString stringWithUTF8String:value] : nil;
            }
            if (identifier.length) found[identifier] = path;
            bad_query_release(lease);
        }
        maps[@(kind)] = found;
        return found;
    }
}

NSArray<NSString *> *MCMEnumerateIdentifiersForClass(uint64_t kind, NSUInteger limit, NSString **error)
{
    NSArray *identifiers = [[QueryContainers(kind) allKeys] sortedArrayUsingSelector:@selector(compare:)];
    if (error) *error = @"worse_query/pathleak discovery (bounded inode scan)";
    return [identifiers subarrayWithRange:NSMakeRange(0, MIN(limit, identifiers.count))];
}

NSString *MCMContainerPathForIdentifier(uint64_t kind, NSString *identifier, BOOL group, NSString **error)
{
    (void)group;
    if (!identifier.length) return nil;
    if (!FilzaWorseQueryReady()) {
        if (error) *error = FilzaWorseQueryConfigurationStatus();
        return nil;
    }
    NSString *path = QueryContainers(kind)[identifier];
    if (error) *error = path ? @"worse_query metadata map" :
        @"No worse_query container found; check App Group provisioning and scan coverage";
    return path;
}

int64_t MCMActivateContainer(uint64_t kind, NSString *identifier, BOOL group, NSString **error)
{
    NSString *path = MCMContainerPathForIdentifier(kind, identifier, group, error);
    if (!path) return -1;
    int64_t lease = bad_query((char *)path.fileSystemRepresentation, true, NULL, false);
    DIR *dir = lease >= 0 ? opendir(path.fileSystemRepresentation) : NULL;
    if (!dir) {
        bad_query_release(lease);
        if (error) *error = @"worse_query did not provide readable directory access";
        return -1;
    }
    closedir(dir);
    return lease; // Caller releases via bad_query_release (worse_query).
}

NSString *MCMActivateContainerPath(uint64_t kind, NSString *identifier, BOOL group, NSString **error)
{
    static NSMutableDictionary *leases;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ leases = [NSMutableDictionary new]; });
    NSString *path = MCMContainerPathForIdentifier(kind, identifier, group, error);
    if (!path) return nil;
    @synchronized (leases) {
        if (!leases[path]) {
            int64_t handle = MCMActivateContainer(kind, identifier, group, error);
            if (handle < 0) return nil;
            leases[path] = @(handle);
        }
    }
    return path;
}
