#import <Foundation/Foundation.h>
#import "COMergeResult.h"

/**
 * Superclass of COStringDiff and COArrayDiff, which implements merging.
 */
@interface COSequenceDiff : NSObject
{
	NSMutableArray *ops;
}

- (id) initWithOperations: (NSArray*)opers;
- (NSArray *)operations;

- (COMergeResult *)mergeWith: (COSequenceDiff *)other;

@end


@interface COSequenceDiffOperation : NSObject
{
	NSRange range;
}
@property (nonatomic, assign, readonly) NSRange range;

- (NSComparisonResult) compare: (COSequenceDiffOperation *)obj;

@end