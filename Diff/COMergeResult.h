#import <Foundation/Foundation.h>

/**
 * FIXME: This whole API is ugly
 */

/**
 * Operations which conflicted at one location.
 *
 * One of |opsFromBase| and |opsFromOther| is gauranteed to contain exactly one
 * element, and the other will contain at least one.
 */
@interface COMergeConflict : NSObject
{
	NSArray *opsFromBase;
	NSArray *opsFromOther;
}
@property (nonatomic, readonly, retain) NSArray *opsFromBase;             
@property (nonatomic, readonly, retain) NSArray *opsFromOther;
@end

/**
 * The value returned when two COStringDiff/COArrayDiff/COSetDiff's are merged.
 */
@interface COMergeResult : NSObject
{
	NSArray *nonoverlappingNonconflictingOps;
	NSArray *overlappingNonconflictingOps;
	NSArray *conflicts;
}

/**
 * Operations from base or other which didn't conflict
 *
 * FIXME: should be annotated with which side the operation came from.
 */
@property (nonatomic, readonly, retain) NSArray *nonoverlappingNonconflictingOps;
/**
 * Operations which were present in both base and other (i.e. both diffs 
 * made the same change)
 */
@property (nonatomic, readonly, retain) NSArray *overlappingNonconflictingOps;
/**
 * COMergeConflict objects representing operations which conflicted
 */
@property (nonatomic, readonly, retain) NSArray *conflicts;

- (NSArray *)nonconflictingOps;

@end


@interface COMergeConflict (Private)
+ (COMergeConflict*)conflictWithOpsFromBase: (NSArray*)a
                               opsFromOther: (NSArray*)b;
@end

@interface COMergeResult (Private)
+ (COMergeResult*)resultWithNonoverlappingNonconflictingOps: (NSArray *)a
                               overlappingNonconflictingOps: (NSArray *)b
                                                  conflicts: (NSArray *)c;
@end