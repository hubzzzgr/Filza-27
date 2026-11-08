#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Legacy names retained only for embedded callers. All discovery and grants
// below use pathleak/worse_query; no MobileContainerManager query API is used.
FOUNDATION_EXPORT BOOL MCMBridgeAvailable(void);
FOUNDATION_EXPORT NSArray<NSString *> *MCMEnumerateIdentifiersForClass(
    uint64_t containerClass, NSUInteger limit, NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSString * _Nullable MCMContainerPathForIdentifier(
    uint64_t containerClass, NSString *identifier, BOOL group, NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSString * _Nullable MCMActivateContainerPath(
    uint64_t containerClass, NSString *identifier, BOOL group, NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT int64_t MCMActivateContainer(
    uint64_t containerClass, NSString *identifier, BOOL group, NSString * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
