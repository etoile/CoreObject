#import "COMergeResult.h"

@implementation COMergeConflict

@synthesize opsFromBase;
@synthesize opsFromOther;

- (void) dealloc
{
	[opsFromBase release];
	[opsFromOther release];
	[super dealloc];
}

@end

@implementation COMergeConflict (Private)
+ (COMergeConflict*)conflictWithOpsFromBase: (NSArray*)a
                               opsFromOther: (NSArray*)b
{
	COMergeConflict *conflict = [[[COMergeConflict alloc] init] autorelease];
	
	if (!(([a count] == 1 && [b count] >= 1) || ([a count] >= 1 && [b count] == 1)))
	{
		[NSException raise: NSInvalidArgumentException format: @"COMergeConflict invalid ops count"];
	}
	
	conflict->opsFromBase = [a retain];
	conflict->opsFromOther = [b retain];
	return conflict;
}

@end


@implementation COMergeResult

@synthesize nonoverlappingNonconflictingOps;
@synthesize overlappingNonconflictingOps;
@synthesize conflicts;

- (void) dealloc
{
	[nonoverlappingNonconflictingOps release];
	[overlappingNonconflictingOps release];
	[conflicts release];
	[super dealloc];
}

- (NSArray *)nonconflictingOps
{
	return [nonoverlappingNonconflictingOps arrayByAddingObjectsFromArray: 
			overlappingNonconflictingOps];
}

@end

@implementation COMergeResult (Private)

+ (COMergeResult*)resultWithNonoverlappingNonconflictingOps: (NSArray *)a
                               overlappingNonconflictingOps: (NSArray *)b
                                                  conflicts: (NSArray *)c
{
	COMergeResult *result = [[[COMergeResult alloc] init] autorelease];
	result->nonoverlappingNonconflictingOps = [a retain];
	result->overlappingNonconflictingOps = [b retain];
	result->conflicts = [c retain];
	return result;
}

@end
