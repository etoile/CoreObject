// Needed to allow limits.h stuff to work in C++ (otherwise INTPTR_MAX is undefined)
// Now included in GSConfig.h since August 20 2012, see GNUstep Base SVN r35433
#define __STDC_LIMIT_MACROS

#import <EtoileFoundation/EtoileFoundation.h>
#import "COArrayDiff.h"
#include "diff.hh"

class NSArrayWrapper
{
private:
	NSArray *arr1, *arr2;
	id (*objectAtIndexIMP1)(id, SEL, NSUInteger);
	id (*objectAtIndexIMP2)(id, SEL, NSUInteger);
public:
	bool equal(size_t i, size_t j)
	{
		id left = objectAtIndexIMP1(arr1, @selector(objectAtIndex:), i);
		id right = objectAtIndexIMP2(arr2, @selector(objectAtIndex:), j);
		
		return [left isEqual: right];
	}
	NSArrayWrapper(NSArray *a1, NSArray *a2) : arr1(a1), arr2(a2)
	{
		[arr1 retain];
		[arr2 retain];
		objectAtIndexIMP1 = (id (*)(id, SEL, NSUInteger))[arr1 methodForSelector: @selector(objectAtIndex:)];
		objectAtIndexIMP2 = (id (*)(id, SEL, NSUInteger))[arr2 methodForSelector: @selector(objectAtIndex:)];
	}
	~NSArrayWrapper()
	{
		[arr1 release];
		[arr2 release];
	}
};

@interface COArrayDiff (Private)

- (void)diffWithA: (NSArray*)a B: (NSArray*)b;

@end

@implementation COArrayDiff

- (id) initWithFirstArray: (NSArray *)first secondArray: (NSArray *)second
{
	SUPERINIT;
	[self diffWithA:first
				  B:second];
	return self;
}

- (void) dealloc
{
	[ops release];
	[super dealloc];
}

- (void)diffWithA: (NSArray*)a B: (NSArray*)b
{
	ops = [[NSMutableArray alloc] init];
	
	//NSLog(@"ArrayDiffing %d vs %d objects", [a count], [b count]);
	
	NSArrayWrapper wrapper(a, b);
	std::vector<ManagedFusion::DifferenceItem> items = 
    ManagedFusion::Diff<NSArrayWrapper>(wrapper, [a count], [b count]);
	
	for (std::vector<ManagedFusion::DifferenceItem>::iterator it = items.begin();
		 it != items.end();
		 it++)
	{
		NSRange firstRange = NSMakeRange((*it).rangeInA.location, (*it).rangeInA.length);
		NSRange secondRange = NSMakeRange((*it).rangeInB.location, (*it).rangeInB.length);
		
		switch ((*it).type)
		{
			case ManagedFusion::INSERTION:
				if (secondRange.length > 0)
				{
					[ops addObject: [COArrayDiffOperationInsert insertWithLocation: firstRange.location
																		   objects: [b subarrayWithRange: secondRange]]];
				}
				break;
			case ManagedFusion::DELETION:
				[ops addObject: [COArrayDiffOperationDelete deleteWithRange: firstRange]];
				break;
			case ManagedFusion::MODIFICATION:
				[ops addObject: [COArrayDiffOperationModify modifyWithRange: firstRange
																 newObjects: [b subarrayWithRange: secondRange]]];
				break;
		}
	}
}



/**
 * Applys the receiver to the given mutable array
 */
- (void) applyTo: (NSMutableArray*)array
{
	NSInteger i = 0;
	for (COSequenceDiffOperation *op in ops)
	{
		if ([op isKindOfClass: [COArrayDiffOperationInsert class]])
		{
			COArrayDiffOperationInsert *opp = (COArrayDiffOperationInsert*)op;
			NSRange range = NSMakeRange([op range].location + i, [[opp insertedObjects] count]);
			
			[array insertObjects: [opp insertedObjects]
					   atIndexes: [NSIndexSet indexSetWithIndexesInRange: range]];
			
			i += range.length;
		}
		else if ([op isKindOfClass: [COArrayDiffOperationDelete class]])
		{
			NSRange range = NSMakeRange([op range].location + i, [op range].length);
			
			[array removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange: range]];
			i -= range.length;
		}
		else if ([op isKindOfClass: [COArrayDiffOperationModify class]])
		{
			COArrayDiffOperationModify *opp = (COArrayDiffOperationModify*)op;
			NSRange deleteRange = NSMakeRange([opp range].location + i, [opp range].length);
			NSRange insertRange = NSMakeRange([opp range].location + i, [[opp insertedObjects] count]);
			
			[array removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange: deleteRange]];
			[array insertObjects: [opp insertedObjects]
					   atIndexes: [NSIndexSet indexSetWithIndexesInRange: insertRange]];
			i += (insertRange.length - deleteRange.length);
		}
		else
		{
			assert(0);
		}    
	}
}

- (NSArray *)arrayWithDiffAppliedTo: (NSArray *)array
{
	NSMutableArray *mutableArray = [NSMutableArray arrayWithArray: array];
	[self applyTo: mutableArray];
	return mutableArray;
}

@end





@implementation COArrayDiffOperationInsert 

@synthesize insertedObjects;

+ (COArrayDiffOperationInsert*)insertWithLocation: (NSUInteger)loc objects: (NSArray*)objs
{
	COArrayDiffOperationInsert *op = [[[COArrayDiffOperationInsert alloc] init] autorelease];
	op->range = NSMakeRange(loc, 0);
	op->insertedObjects = [objs retain];
	assert([objs count] > 0);
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Insert '%@' at %lu", insertedObjects, (unsigned long)range.location];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COArrayDiffOperationInsert class]])
	{
		COArrayDiffOperationInsert *o = other;
		return NSEqualRanges([o range], [self range]) &&
		[[o insertedObjects] isEqual: [self insertedObjects]];
	}
	return NO;
}

- (void) dealloc
{
	[insertedObjects release];
	[super dealloc];
}

@end

@implementation COArrayDiffOperationDelete

+ (COArrayDiffOperationDelete*)deleteWithRange: (NSRange)range
{
	COArrayDiffOperationDelete *op = [[[COArrayDiffOperationDelete alloc] init] autorelease];
	op->range = range;
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Delete '%@'", NSStringFromRange(range)];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COArrayDiffOperationDelete class]])
	{
		COArrayDiffOperationDelete *o = other;
		return NSEqualRanges([o range], [self range]);
	}
	return NO;
}

@end

@implementation COArrayDiffOperationModify

@synthesize insertedObjects;

+ (COArrayDiffOperationModify*)modifyWithRange: (NSRange)range newObjects: (NSArray*)objs
{
	COArrayDiffOperationModify *op = [[[COArrayDiffOperationModify alloc] init] autorelease];
	op->range = range;
	op->insertedObjects = [objs retain];
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Modify '%@' to '%@'", NSStringFromRange(range), insertedObjects];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COArrayDiffOperationModify class]])
	{
		COArrayDiffOperationModify *o = other;
		return NSEqualRanges([o range], [self range]) &&
		[[o insertedObjects] isEqual: [self insertedObjects]];
	}
	return NO;
}

- (void) dealloc
{
	[insertedObjects release];
	[super dealloc];
}

@end

