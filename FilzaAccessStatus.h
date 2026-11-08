#import <Foundation/Foundation.h>

// Snapshots of read-only observations made during ordinary worse_query calls.
// These are historical observations, not a promise of current/future access.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *FilzaWorseQueryObservedAccess(void);
