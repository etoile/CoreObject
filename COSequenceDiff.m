#import <EtoileFoundation/EtoileFoundation.h>
#import "COSequenceDiff.h"

@implementation COSequenceDiffOperation

@synthesize range;

- (NSComparisonResult) compare: (COSequenceDiffOperation*)other
{
	if ([other range].location > [self range].location)
	{
		return NSOrderedAscending;
	}
	if ([other range].location == [self range].location)
	{
		return NSOrderedSame;
	}
	else
	{
		return NSOrderedDescending;
	}
}

- (BOOL) overlaps: (COSequenceDiffOperation *)other
{
	NSRange r1 = [self range];
	NSRange r2 = [other range];
	return (r1.location >= r2.location && r1.location < (r2.location + r2.length) && r1.length > 0)
    || (r2.location >= r1.location && r2.location < (r1.location + r1.length) && r2.length > 0);
}

@end


@implementation COSequenceDiff

- (id) initWithOperations: (NSArray*)opers
{
	SUPERINIT;
	ops = [opers mutableCopy];
	return self;
}

- (NSArray *)operations
{
	return ops;
}

- (NSString*)description
{
	NSMutableString *output = [NSMutableString stringWithFormat: @"<%@ %p: ", NSStringFromClass([self class]), self];
	for (id op in [self operations])
	{
		[output appendFormat:@"\n\t%@,", op];
	}
	[output appendFormat:@"\n>"];  
	return output;
}

/**
 * Inspired by the description of diff3 in "A Formal Investigation of diff3"
 */
- (COMergeResult *)mergeWith: (COSequenceDiff *)other
{
	// Output arrays
	NSMutableArray *nonoverlappingNonconflictingOps = [NSMutableArray array];
	NSMutableArray *overlappingNonconflictingOps = [NSMutableArray array];
	NSMutableArray *conflicts = [NSMutableArray array];
    
	NSArray *oa = [self operations];
	NSArray *ob = [other operations];
	
	NSUInteger count_oa = [oa count];
	NSUInteger count_ob = [ob count];
	
	if (count_oa == 0)
	{
		[nonoverlappingNonconflictingOps addObjectsFromArray: ob];
	}
	else if (count_ob == 0)
	{
		[nonoverlappingNonconflictingOps addObjectsFromArray: oa];
	}
	else if (count_oa > 0 && count_ob > 0)
	{
		const NSUInteger sorted_count = count_oa + count_ob;
		BOOL *sorted_source_is_oa = malloc(sorted_count * sizeof(BOOL));
		NSUInteger *sorted_source_index = malloc(sorted_count * sizeof(NSUInteger));
		
		// Sort the union of oa and ob
		NSUInteger i_oa = 0;
		NSUInteger i_ob = 0;    
		for (NSUInteger i_sorted = 0; i_sorted < sorted_count; i_sorted++)
		{
			if (i_oa < count_oa && i_ob == count_ob)
			{
				sorted_source_is_oa[i_sorted] = YES;
				sorted_source_index[i_sorted] = i_oa;
				i_oa++;
			}
			else if (i_ob < count_ob && i_oa == count_oa)
			{
				sorted_source_is_oa[i_sorted] = NO;
				sorted_source_index[i_sorted] = i_ob;
				i_ob++;
			}
			else
			{
				if ([[oa objectAtIndex: i_oa] compare: [ob objectAtIndex: i_ob]] == NSOrderedAscending)
				{
					sorted_source_is_oa[i_sorted] = YES;
					sorted_source_index[i_sorted] = i_oa;
					i_oa++;        
				}
				else
				{
					sorted_source_is_oa[i_sorted] = NO;
					sorted_source_index[i_sorted] = i_ob;
					i_ob++;
				}
			}
		}
		
		// Walk through the sorted oa and ob
		
		NSMutableSet *overlappingFromA = [[NSMutableSet alloc] init];
		NSMutableSet *overlappingFromB = [[NSMutableSet alloc] init];    
		for (NSUInteger i=0; i < sorted_count; i++)
		{
			COSequenceDiffOperation *op1 = [(sorted_source_is_oa[i] ? oa : ob) objectAtIndex: sorted_source_index[i]];
			
			// Does the operation after op1 overlap op1?
			[overlappingFromA removeAllObjects];
			[overlappingFromB removeAllObjects];
			if (sorted_source_is_oa[i])
			{
				[overlappingFromA addObject: op1];
			}
			else
			{
				[overlappingFromB addObject: op1];
			}
			BOOL allSame = YES;
			
			while (i+1 < sorted_count)
			{
				COSequenceDiffOperation *op2 = [(sorted_source_is_oa[i+1] ? oa : ob) objectAtIndex: sorted_source_index[i+1]];
				if ([op1 overlaps: op2])
				{
					if (sorted_source_is_oa[i+1])
					{
						[overlappingFromA addObject: op2];
					}
					else
					{
						[overlappingFromB addObject: op2];
					}
					allSame = allSame && [op2 isEqual: op1];
					i++;
				}
				else
				{
					break;
				}
			}
			
			// Process the overlapping operations
			if ([overlappingFromA count] + [overlappingFromB count] > 1)
			{
				if (allSame)
				{
					[overlappingNonconflictingOps addObject: op1];        
				}
				else
				{
					[conflicts addObject: [COMergeConflict conflictWithOpsFromBase: [overlappingFromA allObjects]
																	  opsFromOther: [overlappingFromB allObjects]]];
				}
			}
			else
			{
				[nonoverlappingNonconflictingOps addObject: op1];
			}
		}
		
		[overlappingFromA release];
		[overlappingFromB release];
		
		free(sorted_source_is_oa);
		free(sorted_source_index);
	}
	
	return [COMergeResult resultWithNonoverlappingNonconflictingOps: nonoverlappingNonconflictingOps
									   overlappingNonconflictingOps: overlappingNonconflictingOps
														  conflicts: conflicts];
}

@end
