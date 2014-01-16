/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"
#import "COAttributedStringDiff.h"
#import "COAttributedStringWrapper.h"
#include "diff.h"

// FIXME: Hack to get -insertObjects:atIndexes:hints:forProperty:
#import "COObject+Private.h"

@implementation COAttributedStringDiff

@synthesize operations = _operations;

static bool arraycomparefn(size_t i, size_t j, const void *userdata1, const void *userdata2)
{
	return [(__bridge NSString *)userdata1 characterAtIndex: i]
	== [(__bridge NSString *)userdata2 characterAtIndex: j];
}

static BOOL coalesceOpPair(id<COAttributedStringDiffOperation> op, id<COAttributedStringDiffOperation> nextOp)
{
	const BOOL isOpAttributeOp = ([op isKindOfClass: [COAttributedStringDiffOperationAddAttribute class]]
								  || [op isKindOfClass: [COAttributedStringDiffOperationRemoveAttribute class]]);
	const BOOL isOpSameClassAsNextOp = ([op class] == [nextOp class]);
	const BOOL isAdjacent = NSMaxRange([op range]) == [nextOp range].location;
	
	if (isOpAttributeOp && isOpSameClassAsNextOp && isAdjacent)
	{
		COObjectGraphContext *opAttributeGraph = [COObjectGraphContext new];
		[opAttributeGraph setItemGraph: [(COAttributedStringDiffOperationAddAttribute *)op attributeItemGraph]];
		COAttributedStringAttribute *opAttribute = [opAttributeGraph rootObject];
		
		COObjectGraphContext *nextOpAttributeGraph = [COObjectGraphContext new];
		[nextOpAttributeGraph setItemGraph: [(COAttributedStringDiffOperationAddAttribute *)nextOp attributeItemGraph]];
		COAttributedStringAttribute *nextOpAttribute = [nextOpAttributeGraph rootObject];
		
		const BOOL sameAttributes = [opAttribute isEqual: nextOpAttribute];
		if (sameAttributes)
		{
			op.range = NSMakeRange(op.range.location, op.range.length + nextOp.range.length);
			return YES;
		}
	}
	return NO;
}

static void coalesceOpsInternal(NSMutableArray *ops, NSUInteger i)
{
	if (i+1 >= [ops count])
		return;
	
	if (coalesceOpPair(ops[i], ops[i+1]))
	{
		[ops removeObjectAtIndex: i+1];
		coalesceOpsInternal(ops, i);
	}
	else
	{
		return coalesceOpsInternal(ops, i+1);
	}
}

static void coalesceOps(NSMutableArray *ops)
{
	coalesceOpsInternal(ops, 0);
}

+ (instancetype) diffItemUUIDs: (NSArray *)uuids
					 fromGraph: (id <COItemGraph>)a
					   toGraph: (id <COItemGraph>)b
			  sourceIdentifier: (id)aSource
{
	// FIXME: Ugly hack.
	COObjectGraphContext *ctxA = [[COObjectGraphContext alloc] init];
	[ctxA setItemGraph: a];
	COObjectGraphContext *ctxB = [[COObjectGraphContext alloc] init];
	[ctxB setItemGraph: b];
	
	COAttributedStringDiff *result = [[COAttributedStringDiff alloc] init];
	result->_operations = [NSMutableArray new];
	
	for (ETUUID *uuid in uuids)
	{
		COAttributedString *objectA = [ctxA loadedObjectForUUID: uuid];
		COAttributedString *objectB = [ctxB loadedObjectForUUID: uuid];
		
		// HACK: -diffFirst: method won't handle one string being nil, so just
		// make a fake string.
		if (objectA == nil)
		{
			objectA = [[COAttributedString alloc] prepareWithUUID: uuid
												entityDescription: [[ctxA modelDescriptionRepository] entityDescriptionForClass: [COAttributedString class]]
											   objectGraphContext: ctxA
															isNew: YES];
		}
		
		if ([objectB isKindOfClass: [COAttributedString class]])
		{
			[result diffFirst:objectA second: objectB source: aSource];
		}
	}

	return result;
}

- (id<CODiffAlgorithm>) itemTreeDiffByMergingWithDiff: (id<CODiffAlgorithm>)aDiff
{
	COAttributedStringDiff *result = [COAttributedStringDiff new];
	result->_operations = [NSMutableArray new];
	[result addOperationsFromDiff: self];
	[result addOperationsFromDiff: (COAttributedStringDiff *)aDiff];
	return result;
}

- (instancetype) initWithFirstAttributedString: (COAttributedString *)first
						secondAttributedString: (COAttributedString *)second
										source: (id)source
{
	SUPERINIT;
	_operations = [NSMutableArray new];
	[self diffFirst: first second: second source: source];
	return self;
}

- (void) diffFirst: (COAttributedString *)first
			second: (COAttributedString *)second
			source: (id)source
{
	NSString *firstString = [[[COAttributedStringWrapper alloc] initWithBacking: first] string];
	NSString *secondString = [[[COAttributedStringWrapper alloc] initWithBacking: second] string];
		
	diffresult_t *result = diff_arrays([firstString length], [secondString length], arraycomparefn, (__bridge void *)firstString, (__bridge void *)secondString);
	
	for (size_t i = 0; i < diff_editcount(result); i++)
	{
		const diffedit_t edit = diff_edit_at_index(result, i);
		const NSRange rangeInA = NSMakeRange(edit.range_in_a.location, edit.range_in_a.length);
		const NSRange rangeInB = NSMakeRange(edit.range_in_b.location, edit.range_in_b.length);
		
		switch (edit.type)
		{
			case difftype_insertion:
				[self recordInsertionRangeA: rangeInA rangeB: rangeInB first: first second: second source: source];
				break;
			case difftype_deletion:
				[self recordDeletionRangeA: rangeInA rangeB: rangeInB first: first second: second source: source];
				break;
			case difftype_modification:
				[self recordModificationRangeA: rangeInA rangeB: rangeInB first: first second: second source: source];
				break;
			case difftype_copy:
				[self recordCopyRangeA: rangeInA rangeB: rangeInB first: first second: second source: source];
				break;
		}
	}
	
	diff_free(result);
	
	// To make testing easier
	coalesceOps(_operations);
}

- (void) recordInsertionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	COItemGraph *graph = [second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
	op.attributedStringUUID = second.UUID;
	op.range = rangeInA;
	op.source = source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordDeletionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	COAttributedStringDiffOperationDeleteRange *op = [COAttributedStringDiffOperationDeleteRange new];
	op.attributedStringUUID = second.UUID;
	op.range = rangeInA;
	op.source = source;
	
	[_operations addObject: op];
}

- (void) recordModificationRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	// The semantics of "modification" are that the old and new
	// block are totally unrelated. Thus the old and new attributes
	// are totally semantically unrelated, so we just record it in the diff as
	// 'replace this range with this new attributed string'
	
	COItemGraph *graph = [second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationReplaceRange *op = [COAttributedStringDiffOperationReplaceRange new];
	op.attributedStringUUID = second.UUID;
	op.range = rangeInA;
	op.source = source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordAddAttribute: (COAttributedStringAttribute *)attr toRangeA: (NSRange)rangeInA first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	COItemGraph *graph = [attr attributeItemGraph];
	
	COAttributedStringDiffOperationAddAttribute *op = [COAttributedStringDiffOperationAddAttribute new];
	op.range = rangeInA;
	op.source = source;
	op.attributeItemGraph = graph;
	op.attributedStringUUID = second.UUID;
	
	[_operations addObject: op];
}

- (void) recordRemoveAttribute: (COAttributedStringAttribute *)attr toRangeA: (NSRange)rangeInA first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	COItemGraph *graph = [attr attributeItemGraph];
	
	COAttributedStringDiffOperationRemoveAttribute *op = [COAttributedStringDiffOperationRemoveAttribute new];
	op.range = rangeInA;
	op.source = source;
	op.attributeItemGraph = graph;
	op.attributedStringUUID = second.UUID;
	
	[_operations addObject: op];
}

- (void) recordCopyRangeA: (NSRange)firstRange rangeB: (NSRange)secondRange first: (COAttributedString *)first second: (COAttributedString *)second source: (id)source
{
	// The textual content of these regions is unchanged. Iterate
	// through the attributes and see if they are the same too.
	
	ETAssert(firstRange.length == secondRange.length);
	
	NSUInteger i=0;
	while (i<firstRange.length)
	{
		NSRange rangeAtIForFirstString;
		NSRange rangeAtIForSecondString;
		NSSet *firstAttributes = [first attributesSetAtIndex: firstRange.location + i
										longestEffectiveRange: &rangeAtIForFirstString
													  inRange: firstRange];
		NSSet *secondAttributes = [second attributesSetAtIndex: secondRange.location + i
										  longestEffectiveRange: &rangeAtIForSecondString
														inRange: secondRange];
		
		if (rangeAtIForFirstString.location < firstRange.location + i)
		{
			rangeAtIForFirstString.length -= (firstRange.location + i) - rangeAtIForFirstString.location;
			rangeAtIForFirstString.location = firstRange.location + i;
		}
		
		if (rangeAtIForSecondString.location < secondRange.location + i)
		{
			rangeAtIForSecondString.length -= (secondRange.location + i) - rangeAtIForSecondString.location;
			rangeAtIForSecondString.location = secondRange.location + i;
		}
		
		const NSUInteger minLength = MIN(rangeAtIForFirstString.length, rangeAtIForSecondString.length);
		ETAssert(minLength >= 1);
		const NSRange consideredRangeForFirstString = NSMakeRange(rangeAtIForFirstString.location,  minLength);
		
		if (![firstAttributes isEqual: secondAttributes])
		{
			{
				NSMutableSet *removed = [NSMutableSet setWithSet: firstAttributes];
				[removed minusSet: secondAttributes];
				
				for (COAttributedStringAttribute *attr in removed)
				{
					[self recordRemoveAttribute: attr toRangeA: consideredRangeForFirstString first: first second: second source: source];
				}
			}
			{
				NSMutableSet *added = [NSMutableSet setWithSet: secondAttributes];
				[added minusSet: firstAttributes];
				
				for (COAttributedStringAttribute *attr in added)
				{
					[self recordAddAttribute: attr toRangeA: consideredRangeForFirstString first: first second: second source: source];
				}
			}
		}
		
		i += minLength;
	}
}

#pragma mark - Diff Application

- (void) sortOperationsFavouringSourceIdentifier: (id)aSource
{
	[_operations sortUsingComparator: ^(id obj1, id obj2){
		id<COAttributedStringDiffOperation> string1 = obj1;
		id<COAttributedStringDiffOperation> string2 = obj2;
		
		if (![string1.attributedStringUUID isEqual: string2.attributedStringUUID])
		{
			int result = memcmp([string1.attributedStringUUID UUIDValue], [string2.attributedStringUUID UUIDValue], 16);
			return (result < 0) ? NSOrderedAscending : NSOrderedDescending;
		}
		
		NSRange r1 = string1.range;
		NSRange r2 = string2.range;
		
		if (r1.location < r2.location)
		{
			return NSOrderedAscending;
		}
		if (r1.location == r2.location)
		{
			if ([aSource isEqual: [string1 source]])
			{
				return NSOrderedAscending;
			}
			if ([aSource isEqual: [string2 source]])
			{
				return NSOrderedDescending;
			}
			
			return NSOrderedSame;
		}
		else
		{
			return NSOrderedDescending;
		}
	}];
	
	// To make testing easier
	coalesceOps(_operations);
}

- (void) addOperationsFromDiff: (COAttributedStringDiff *)aDiff
{
	[_operations addObjectsFromArray: aDiff.operations];
	
	[self sortOperationsFavouringSourceIdentifier: nil];
}

- (COAttributedStringDiff *) diffByMergingWithDiff: (COAttributedStringDiff *)aDiff
{
	COAttributedStringDiff *result = [COAttributedStringDiff new];
	result->_operations = [NSMutableArray new];
	[result->_operations addObjectsFromArray: _operations];
	[result->_operations addObjectsFromArray: [aDiff operations]];
	[result sortOperationsFavouringSourceIdentifier: nil];
	return result;
}

- (NSDictionary *) operationArraysByUUID
{
	NSMutableDictionary *operationArrays = [NSMutableDictionary new];
	for (id<COAttributedStringDiffOperation>op in _operations)
	{
		NSMutableArray *array = operationArrays[op.attributedStringUUID];
		if (array == nil)
		{
			array = [NSMutableArray new];
			operationArrays[op.attributedStringUUID] = array;
		}
		[array addObject: op];
	}
	return operationArrays;
}

- (NSDictionary *) addedOrUpdatedItemsForApplyingTo: (id<COItemGraph>)dest
{
	COObjectGraphContext *workingCtx = [[COObjectGraphContext alloc] init];
	[workingCtx setItemGraph: dest];
	
	[self applyToObjectGraph: workingCtx];

	// Sort of a hack..
	
	COItemGraphDiff *diff = [COItemGraphDiff diffItemTree: dest withItemTree: workingCtx sourceIdentifier: @""];
	NSDictionary *result = [diff addedOrUpdatedItemsForApplyingTo: dest];
	return result;
}

- (void) applyToAttributedString: (COAttributedString *)attrStr
{
	NSDictionary *operationArraysByUUID = [self operationArraysByUUID];
	NSArray *array = operationArraysByUUID[attrStr.UUID];
	NSInteger i = 0;
	for (id<COAttributedStringDiffOperation> op in array)
	{
		NSLog(@"Applying %@", op);
		
		i += [op applyOperationToAttributedString: attrStr withOffset: i];
	}
}

- (void) applyToObjectGraph: (COObjectGraphContext *)dest
{
	NSDictionary *operationArraysByUUID = [self operationArraysByUUID];
	for (ETUUID *attributedStringUUID in operationArraysByUUID)
	{
		COAttributedString *attrStr = [dest loadedObjectForUUID: attributedStringUUID];
		if (attrStr == nil)
		{
			attrStr = [[COAttributedString alloc] prepareWithUUID: attributedStringUUID
												entityDescription: [[dest modelDescriptionRepository] entityDescriptionForClass: [COAttributedString class]]
											   objectGraphContext: dest
															isNew: YES];
		}
		
		NSArray *array = operationArraysByUUID[attributedStringUUID];
		NSInteger i = 0;
		for (id<COAttributedStringDiffOperation> op in array)
		{
			NSLog(@"Applying %@", op);
			
			i += [op applyOperationToAttributedString: attrStr withOffset: i];
		}
	}
}

- (BOOL) hasConflicts
{
	// FIXME: Implement
	return NO;
}

- (void) resolveConflictsFavoringSourceIdentifier: (id)aSource
{
	[self sortOperationsFavouringSourceIdentifier: aSource];
	
	// FIXME: Handle actual conflicts
}

- (NSString *)description
{
	NSMutableString *desc = [NSMutableString stringWithString: [super description]];
	[desc appendFormat: @" {\n"];
	for (COItemGraphEdit *edit in _operations)
	{
		[desc appendFormat: @"\t%@\n", [edit description]];
	}
 	[desc appendFormat: @"}"];
	return desc;
}

@end

#pragma mark - Operation Classes

static NSString *
COHTMLCodesForAttributesItemGraph(COItemGraph *graph)
{
	NSString *htmlCodes = [[[graph items] mappedCollectionWithBlock:
							^(id obj) { return [obj valueForAttribute: @"htmlCode"]; }] componentsJoinedByString: @","];
	return htmlCodes;
}

static NSString *
CODescriptionForAttributedStringItemGraph(COItemGraph *graph)
{
	COObjectGraphContext *tempCtx = [COObjectGraphContext new];
	[tempCtx setItemGraph: graph];
	
	COAttributedString *string = [tempCtx rootObject];
	NSMutableString *result = [NSMutableString new];
	for (COAttributedStringChunk *chunk in string.chunks)
	{
		[result appendFormat: @"%@", chunk];
	}
	
	return result;
}


@implementation COAttributedStringDiffOperationInsertAttributedSubstring
@synthesize range, source, attributedStringItemGraph, attributedStringUUID;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	COObjectGraphContext *targetCtx = [target objectGraphContext];
	const NSInteger insertionPos = range.location + offset;
		
	[targetCtx insertOrUpdateItems: [attributedStringItemGraph items]];
	
	COAttributedString *sourceString = [targetCtx loadedObjectForUUID: [attributedStringItemGraph rootItemUUID]];
	const NSUInteger sourceStringLength = [sourceString length];
	const NSInteger insertionPosChunkIndex = [target splitChunkAtIndex: insertionPos];
		
	// FIXME: Why is -insertObjects:atIndexes:hints:forProperty: private?!
	[target insertObjects: sourceString.chunks
				atIndexes: [[NSIndexSet alloc] initWithIndexesInRange: NSMakeRange(insertionPosChunkIndex, [sourceString.chunks count])]
					hints: nil
			  forProperty: @"chunks"];
	
	return sourceStringLength;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: insert %@ at %@ (%@)",
			self.attributedStringUUID, CODescriptionForAttributedStringItemGraph(self.attributedStringItemGraph), NSStringFromRange(self.range), self.source];
}

@end

@implementation COAttributedStringDiffOperationDeleteRange
@synthesize range, source, attributedStringUUID;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	const NSInteger deletionStartChunkIndex = [target splitChunkAtIndex: range.location + offset];
	const NSInteger deletionEndChunkIndex = [target splitChunkAtIndex: NSMaxRange(range) + offset];
	
	[[target mutableArrayValueForKey: @"chunks"] removeObjectsInRange: NSMakeRange(deletionStartChunkIndex, deletionEndChunkIndex - deletionStartChunkIndex)];
	
	return -range.length;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: delete %@ (%@)",
			self.attributedStringUUID, NSStringFromRange(self.range), self.source];
}

@end

@implementation COAttributedStringDiffOperationReplaceRange
@synthesize range, source, attributedStringItemGraph, attributedStringUUID;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	COObjectGraphContext *targetCtx = [target objectGraphContext];
	
	[targetCtx insertOrUpdateItems: [attributedStringItemGraph items]];
	COAttributedString *sourceString = [targetCtx loadedObjectForUUID: [attributedStringItemGraph rootItemUUID]];
	const NSUInteger sourceStringLength = [sourceString length];
	
	const NSInteger deletionStartChunkIndex = [target splitChunkAtIndex: range.location + offset];
	const NSInteger deletionEndChunkIndex = [target splitChunkAtIndex: NSMaxRange(range) + offset];
	
	[[target mutableArrayValueForKey: @"chunks"] replaceObjectsInRange: NSMakeRange(deletionStartChunkIndex, deletionEndChunkIndex - deletionStartChunkIndex)
												  withObjectsFromArray: sourceString.chunks];
	
	return sourceStringLength - range.length;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: replace %@ with %@ (%@)",
			self.attributedStringUUID, NSStringFromRange(self.range), CODescriptionForAttributedStringItemGraph(self.attributedStringItemGraph), self.source];
}

@end

@implementation COAttributedStringDiffOperationAddAttribute
@synthesize range, source, attributeItemGraph, attributedStringUUID;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	[target.objectGraphContext insertOrUpdateItems: [attributeItemGraph items]];
	COAttributedStringAttribute *attributeToAdd = [target.objectGraphContext loadedObjectForUUID: [attributeItemGraph rootItemUUID]];
	
	const NSInteger editStartChunkIndex = [target splitChunkAtIndex: range.location + offset];
	const NSInteger editEndChunkIndex = [target splitChunkAtIndex: NSMaxRange(range) + offset];

	for (NSUInteger chunkIndex = editStartChunkIndex; chunkIndex < editEndChunkIndex; chunkIndex++)
	{
		COAttributedStringChunk *chunk = target.chunks[chunkIndex];
		[[chunk mutableSetValueForKey: @"attributes"] addObject: attributeToAdd];
	}
		
	return 0;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: add attrs (%@) to %@ (%@)",
			self.attributedStringUUID, COHTMLCodesForAttributesItemGraph(self.attributeItemGraph), NSStringFromRange(self.range), self.source];
}

@end

@implementation COAttributedStringDiffOperationRemoveAttribute
@synthesize range, source, attributeItemGraph, attributedStringUUID;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	[target.objectGraphContext insertOrUpdateItems: [attributeItemGraph items]];
	COAttributedStringAttribute *attributeToRemove = [target.objectGraphContext loadedObjectForUUID: [attributeItemGraph rootItemUUID]];
	
	const NSInteger editStartChunkIndex = [target splitChunkAtIndex: range.location + offset];
	const NSInteger editEndChunkIndex = [target splitChunkAtIndex: NSMaxRange(range) + offset];
	
	for (NSUInteger chunkIndex = editStartChunkIndex; chunkIndex < editEndChunkIndex; chunkIndex++)
	{
		COAttributedStringChunk *chunk = target.chunks[chunkIndex];
		
		for (COAttributedStringAttribute *attribute in [chunk.attributes copy])
		{
			if ([attribute.htmlCode isEqualToString: attributeToRemove.htmlCode])
			{
				[[chunk mutableSetValueForKey: @"attributes"] removeObject: attribute];
			}
		}
	}
	
	return 0;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: remove attrs (%@) from %@ (%@)",
			self.attributedStringUUID, COHTMLCodesForAttributesItemGraph(self.attributeItemGraph), NSStringFromRange(self.range), self.source];
}

@end
