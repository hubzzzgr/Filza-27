#import "MCMFilzaIntegration.h"
#import "MCMBridge.h"
#import <sys/stat.h>
#import <unistd.h>

// Compatibility function names for Filza's file-operation hooks. This module
// creates local navigation links; worse_query is the only access provider.
NSString *MCMFilzaVirtualRoot(void)
{
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:@"Device Storage"];
}
NSString *MCMFilzaArchivePath(void) { return [MCMFilzaVirtualRoot() stringByAppendingPathComponent:@"Archives"]; }
NSString *MCMFilzaWallpaperLabName(void) { return @"Wallpaper Lab"; }
BOOL MCMFilzaIsRunningInLiveContainer(void) { return NO; }
void MCMFilzaRecordDeletedGeneratedPath(NSString *path) { (void)path; }

BOOL MCMFilzaPathHasActiveLease(NSString *path)
{
    NSString *resolved = path.stringByResolvingSymlinksInPath;
    NSString *ownRoot = NSHomeDirectory().stringByResolvingSymlinksInPath;
    // File-operation routing only; the real filesystem operation checks access.
    return [resolved hasPrefix:[ownRoot stringByAppendingString:@"/"]] ||
        access(resolved.fileSystemRepresentation, R_OK) == 0;
}

NSString *MCMFilzaDataContainerPath(NSString *identifier, NSString **error)
{
    return MCMActivateContainerPath(2, identifier, NO, error);
}

void MCMFilzaStart(void)
{
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *root = MCMFilzaVirtualRoot();
    for (NSString *folder in @[@"App Data", @"App Groups", @"Extension Data", @"Service Data", @"System Data", @"System Groups", @"Archives", @"Wallpaper Lab"])
        [files createDirectoryAtPath:[root stringByAppendingPathComponent:folder]
            withIntermediateDirectories:YES attributes:nil error:nil];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSArray *kinds = @[@2, @7, @4, @10, @12, @13];
            NSArray *folders = @[@"App Data", @"App Groups", @"Extension Data", @"Service Data", @"System Data", @"System Groups"];
            for (NSUInteger index = 0; index < kinds.count; index++) {
                uint64_t kind = [kinds[index] unsignedLongLongValue];
                for (NSString *identifier in MCMEnumerateIdentifiersForClass(kind, 4096, nil)) {
                    if ([identifier containsString:@"/"] || [identifier isEqualToString:@".."] || [identifier isEqualToString:@"."]) continue;
                    NSString *target = MCMActivateContainerPath(kind, identifier, kind == 7 || kind == 13, nil);
                    if (!target) continue;
                    NSString *link = [[root stringByAppendingPathComponent:folders[index]] stringByAppendingPathComponent:identifier];
                    struct stat st;
                    if (lstat(link.fileSystemRepresentation, &st) != 0)
                        symlink(target.fileSystemRepresentation, link.fileSystemRepresentation);
                }
            }
        });
    });
}
