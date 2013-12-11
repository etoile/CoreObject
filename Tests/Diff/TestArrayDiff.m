#import "TestCommon.h"

@interface TestArrayDiff : NSObject <UKTest>
{
	ETUUID *obj;
	NSString *attr;
	NSString *source;
}

@end

@implementation TestArrayDiff

- (id) init
{
	SUPERINIT;
	obj = [ETUUID UUID];
	attr = @"contents";
	source = @"source1";
	return self;
}

- (COSequenceDeletion *) deleteRange: (NSRange)aRange
{
	return  [[COSequenceDeletion alloc] initWithUUID: obj
										   attribute: attr
									sourceIdentifier: source
											   range: aRange];
}

- (COSequenceInsertion *) insertObjects: (NSArray *)objects atIndex: (NSUInteger) anIndex
{
	return [[COSequenceInsertion alloc] initWithUUID: obj
										   attribute: attr
									sourceIdentifier: source
											location: anIndex
												type: kCOTypeArray | kCOTypeString
											 objects: objects];
}

/**
 * This is a corner case - you could consider the diff as having a conflict -
 * but my modified diff3 that doesn't require one common element of "padding"
 * can generate diffs like this. There's only one way to apply it that makes sense.
 */
- (void) testApplyWithOverlappingDeletionAndInsertion
{
	NSArray *edits = @[[self deleteRange: NSMakeRange(0, 1)],
					   [self insertObjects: @[@"y"] atIndex: 0]];
	
	NSMutableArray *array = [@[@"x"] mutableCopy];
	COApplyEditsToArray(array, edits);
	
	UKObjectsEqual(@[@"y"], array);
}

- (void) testApplyWithManyDeletions
{
	NSArray *edits = @[[self deleteRange: NSMakeRange(0, 1)],
					   [self deleteRange: NSMakeRange(2, 1)],
					   [self deleteRange: NSMakeRange(4, 1)]];
	
	NSMutableArray *array = [@[@"0", @"1", @"2", @"3", @"4"] mutableCopy];
	COApplyEditsToArray(array, edits);
	
	UKObjectsEqual((@[@"1", @"3"]), array);
}

- (void) testApplyWithDeletionAndInsertion
{
	NSArray *edits = @[[self deleteRange: NSMakeRange(1, 1)],
					   [self insertObjects: @[@"c"] atIndex: 3]];
	
	NSMutableArray *array = [@[@"a", @"1", @"b"] mutableCopy];
	COApplyEditsToArray(array, edits);
	
	UKObjectsEqual((@[@"a", @"b", @"c"]), array);
}

- (void) testApplyWithInsertionAndDeletion
{
	NSArray *edits = @[[self insertObjects: @[@"b"] atIndex: 1],
					   [self deleteRange: NSMakeRange(2, 1)]];
	
	NSMutableArray *array = [@[@"a", @"c", @"2"] mutableCopy];
	COApplyEditsToArray(array, edits);
	
	UKObjectsEqual((@[@"a", @"b", @"c"]), array);
}


@end