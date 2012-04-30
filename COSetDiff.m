#import <EtoileFoundation/EtoileFoundation.h>
#import "COSetDiff.h"

@implementation COSetDiff

- (id) initWithFirstSet: (NSSet *)first
              secondSet: (NSSet *)second
{
	SUPERINIT;
	
	NSMutableSet *intersection = [[NSMutableSet alloc] initWithSet: first];
	[intersection intersectSet: second];
	
	NSMutableSet *add = [[NSMutableSet alloc] initWithSet: second];
	[add minusSet: intersection];
	
	NSMutableSet *remove = [[NSMutableSet alloc] initWithSet: first];
	[remove minusSet: intersection];
	
	[intersection release];
	
	ops = [[NSMutableArray alloc] init];
	if (![add isEmpty])
	{
		[(NSMutableArray*)ops addObject: [COSetDiffOperationAdd addOperationWithAddedObjects: add]];
		[add release];
	}
	if (![remove isEmpty])
	{
		[(NSMutableArray*)ops addObject: [COSetDiffOperationRemove removeOperationWithRemovedObjects: remove]];
		[remove release];
	}
	
	return self;
}
- (id) initWithOperations: (NSArray *)operations
{
	SUPERINIT;
	ops = [[NSArray alloc] initWithArray: operations];
	return self;
}

- (void) dealloc
{
	[ops release];
	[super dealloc];
}

- (NSArray *)operations
{
	return ops;
}
- (NSSet *)addedObjects
{
	NSMutableSet *added = [NSMutableSet set];
	for (id op in ops)
	{
		if ([op isKindOfClass: [COSetDiffOperationAdd class]])
		{
			[added unionSet: [(COSetDiffOperationAdd*)op addedObjects]];
		}
	}
	return added;
}
- (NSSet *)removedObjects
{
	NSMutableSet *removed = [NSMutableSet set];
	for (id op in ops)
	{
		if ([op isKindOfClass: [COSetDiffOperationRemove class]])
		{
			[removed unionSet: [(COSetDiffOperationRemove*)op removedObjects]];    
		}
	}
	return removed;
}
- (void) applyTo: (NSMutableSet*)set
{
	for (id op in ops)
	{
		[op applyTo: set];
	}
}
- (NSSet *)setWithDiffAppliedTo: (NSSet *)set;
{
	NSMutableSet *mutableSet = [NSMutableSet setWithSet: set];
	[self applyTo: mutableSet];
	return mutableSet;
}

- (COMergeResult *)mergeWith: (COSetDiff *)other;
{  
	// FIXME: this method is a mess, can it be simplified?
	
	NSSet *baseAdded = [self addedObjects];
	NSSet *otherAdded = [other addedObjects];
	NSSet *baseRemoved = [self removedObjects];
	NSSet *otherRemoved = [other removedObjects];
	
	NSMutableSet *overlappingAdds = [NSMutableSet setWithSet: baseAdded];
	[overlappingAdds intersectsSet: otherAdded];
	
	NSMutableSet *overlappingRemoves = [NSMutableSet setWithSet: baseRemoved];
	[overlappingRemoves intersectsSet: otherRemoved];
	
	NSMutableSet *allAdds = [NSMutableSet setWithSet: baseAdded];
	[allAdds unionSet: otherAdded];
	
	NSMutableSet *allRemoves = [NSMutableSet setWithSet: baseRemoved];
	[allRemoves unionSet: otherRemoved];
	
	NSMutableSet *conflicts = [NSMutableSet setWithSet: allAdds];
	[conflicts intersectSet: allRemoves];
	
	NSMutableSet *baseAddedConflicts = [NSMutableSet setWithSet: conflicts];
	[baseAddedConflicts intersectSet: baseAdded];  
	NSMutableSet *baseRemovedConflicts = [NSMutableSet setWithSet: conflicts];
	[baseRemovedConflicts intersectSet: baseRemoved];  
	NSMutableSet *otherAddedConflicts = [NSMutableSet setWithSet: conflicts];
	[otherAddedConflicts intersectSet: otherAdded];
	NSMutableSet *otherRemovedConflicts = [NSMutableSet setWithSet: conflicts];
	[otherRemovedConflicts intersectSet: otherRemoved];
	
	NSMutableSet *nonconflictingNonoverlappingAdds = [NSMutableSet setWithSet: allAdds];
	[nonconflictingNonoverlappingAdds minusSet: overlappingAdds];
	[nonconflictingNonoverlappingAdds minusSet: conflicts];
	
	NSMutableSet *nonconflictingNonoverlappingRemoves = [NSMutableSet setWithSet: allRemoves];
	[nonconflictingNonoverlappingRemoves minusSet: overlappingRemoves];
	[nonconflictingNonoverlappingRemoves minusSet: conflicts];
	
	// Now create operation objects
	
	NSMutableArray *nonoverlappingNonconflictingOps = [NSMutableArray array];
	if (![nonconflictingNonoverlappingAdds isEmpty])
	{
		[nonoverlappingNonconflictingOps addObject: [COSetDiffOperationAdd addOperationWithAddedObjects: nonconflictingNonoverlappingAdds]];
	}
	if (![nonconflictingNonoverlappingRemoves isEmpty])
	{
		[nonoverlappingNonconflictingOps addObject: [COSetDiffOperationRemove removeOperationWithRemovedObjects: nonconflictingNonoverlappingRemoves]];
	}
	
	NSMutableArray *overlappingNonconflictingOps = [NSMutableArray array];
	if (![overlappingAdds isEmpty])
	{
		[overlappingNonconflictingOps addObject: [COSetDiffOperationAdd addOperationWithAddedObjects: overlappingAdds]];
	}
	if (![overlappingRemoves isEmpty])
	{
		[overlappingNonconflictingOps addObject: [COSetDiffOperationRemove removeOperationWithRemovedObjects: overlappingRemoves]];
	}
	
	NSMutableArray *mergeConflicts = [NSMutableArray array];
	if (![baseAddedConflicts isEmpty])
	{
		[mergeConflicts addObject: [COMergeConflict conflictWithOpsFromBase: [NSArray arrayWithObject: [COSetDiffOperationAdd addOperationWithAddedObjects: baseAddedConflicts]]
															   opsFromOther: [NSArray arrayWithObject: [COSetDiffOperationRemove removeOperationWithRemovedObjects: otherRemovedConflicts]]]];
	}
	if (![baseRemovedConflicts isEmpty])
	{
		[mergeConflicts addObject: [COMergeConflict conflictWithOpsFromBase: [NSArray arrayWithObject: [COSetDiffOperationRemove removeOperationWithRemovedObjects: baseRemovedConflicts]]
															   opsFromOther: [NSArray arrayWithObject: [COSetDiffOperationAdd addOperationWithAddedObjects: otherAddedConflicts]]]];    
	}
	
	return [COMergeResult resultWithNonoverlappingNonconflictingOps: nonoverlappingNonconflictingOps
									   overlappingNonconflictingOps: overlappingNonconflictingOps
														  conflicts: mergeConflicts];
}

@end


@implementation COSetDiffOperationAdd
@synthesize addedObjects;
+ (COSetDiffOperationAdd*)addOperationWithAddedObjects: (NSSet*)add
{
	COSetDiffOperationAdd *result = [[[COSetDiffOperationAdd alloc] init] autorelease];
	result->addedObjects = [add retain];
	return result;
}
- (void) dealloc
{
	[addedObjects release];
	[super dealloc];
}
- (void) applyTo: (NSMutableSet*)set
{
	[set unionSet: addedObjects];
}
@end

@implementation COSetDiffOperationRemove
@synthesize removedObjects;
+ (COSetDiffOperationRemove*)removeOperationWithRemovedObjects: (NSSet*)remove
{
	COSetDiffOperationRemove *result = [[[COSetDiffOperationRemove alloc] init] autorelease];
	result->removedObjects = [remove retain];
	return result;
}
- (void) dealloc
{
	[removedObjects release];
	[super dealloc];
}
- (void) applyTo: (NSMutableSet*)set
{
	[set minusSet: removedObjects];
}
@end
