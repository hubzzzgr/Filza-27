#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Snapshots of read-only observations made during ordinary worse_query calls.
// These are historical observations, not a promise of current/future access.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *FilzaWorseQueryObservedAccess(void);

NS_ASSUME_NONNULL_END
