#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COArrayDiff.h"
#import "COStringDiff.h"
#import "TestCommon.h"

@interface TestDiff : TestCommon <UKTest>
@end

@implementation TestDiff

- (void) testArrayDiffMerge
{
	NSArray *array2 = [NSArray arrayWithObjects: @"A", @"c", @"d", @"zoo", @"e", nil];
	NSArray *array1 = [NSArray arrayWithObjects: @"a", @"b", @"c", @"d", @"e", @"f", nil];
	NSArray *array3 = [NSArray arrayWithObjects: @"A", @"b", @"c", @"e", @"foo", nil];
	
	COArrayDiff *diff12 = [[COArrayDiff alloc] initWithFirstArray: array1 secondArray: array2];
	COArrayDiff *diff13 = [[COArrayDiff alloc] initWithFirstArray: array1 secondArray: array3];

	UKObjectsEqual(array2, [diff12 arrayWithDiffAppliedTo: array1]);
	UKObjectsEqual(array3, [diff13 arrayWithDiffAppliedTo: array1]);
	
	COMergeResult *merged = [diff12 mergeWith: diff13];
	NSLog(@"Merge result: %@", merged);
	// FIXME: test the merge result
	//NSLog(@"Expected: a->A, remove b, delete d, insert 'zoo' after d, insert foo after e");
}

@end
