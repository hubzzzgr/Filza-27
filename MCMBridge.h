#import <Foundation/Foundation.h>

// Legacy names retained only for embedded callers. All discovery and grants
// below use pathleak/worse_query; no MobileContainerManager query API is used.
FOUNDATION_EXPORT BOOL MCMBridgeAvailable(void);
FOUNDATION_EXPORT NSArray<NSString *> *MCMEnumerateIdentifiersForClass(uint64_t containerClass, NSUInteger limit, NSString **error);
FOUNDATION_EXPORT NSString *MCMContainerPathForIdentifier(uint64_t containerClass, NSString *identifier, BOOL group, NSString **error);
FOUNDATION_EXPORT NSString *MCMActivateContainerPath(uint64_t containerClass, NSString *identifier, BOOL group, NSString **error);
FOUNDATION_EXPORT int64_t MCMActivateContainer(uint64_t containerClass, NSString *identifier, BOOL group, NSString **error);
