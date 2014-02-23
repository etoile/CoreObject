#import <Foundation/Foundation.h>

@interface BenchmarkCommon : NSObject

/**
 * Returns the time in seconds (as a double) it takes SQLite to commit 1K of random data to a SQLite
 * database on disk in WAL mode.
 *
 * The database is created in NSTemporaryDirectory.
 *
 * The intended use for this method is a reference point for evaluating
 * CoreObject performance.
 *
 * The result is cached after the first time it is calculated.
 */
+ (NSTimeInterval) timeToCommit1KUsingSQLite;

@end
