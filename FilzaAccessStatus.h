#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Snapshots of read-only observations made during ordinary worse_query calls.
// These are historical observations, not a promise of current/future access.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *FilzaWorseQueryObservedAccess(void);

FOUNDATION_EXPORT NSString *FilzaWorseQueryGroupIdentifier(void);
FOUNDATION_EXPORT NSString *FilzaWorseQueryConfigurationStatus(void);
FOUNDATION_EXPORT BOOL FilzaWorseQueryReady(void);
// Returns nil on success. This only selects an already accessible, provisioned group.
FOUNDATION_EXPORT NSString * _Nullable FilzaWorseQueryConfigureGroup(NSString *identifier);
FOUNDATION_EXPORT NSString *FilzaWorseQueryErrorDescription(int64_t result);

NS_ASSUME_NONNULL_END
