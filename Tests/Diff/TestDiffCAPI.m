/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestDiffCAPI : NSObject <UKTest>
@end

@implementation TestDiffCAPI

static bool arraycomparefn(size_t i, size_t j, const void *userdata1, const void *userdata2)
{
	const char *array1 = userdata1;
	const char *array2 = userdata2;
	
	return array1[i] == array2[j];
}

- (void) checkEdit: (diffedit_t)anEdit isCopyFromLocA: (int)locA length: (int)lenA toLocB: (int)locB
{
	UKIntsEqual(locA, anEdit.range_in_a.location);
	UKIntsEqual(lenA, anEdit.range_in_a.length);
	UKIntsEqual(locB, anEdit.range_in_b.location);
	UKIntsEqual(lenA, anEdit.range_in_b.length);
	UKTrue(difftype_copy == anEdit.type);
}

- (void) checkEdit: (diffedit_t)anEdit isDeleteFromLocA: (int)locA length: (int)lenA
{
	UKIntsEqual(locA, anEdit.range_in_a.location);
	UKIntsEqual(lenA, anEdit.range_in_a.length);
	UKIntsEqual(0, anEdit.range_in_b.length);
	UKTrue(difftype_deletion == anEdit.type);
}

- (void) checkEdit: (diffedit_t)anEdit isInsertAtLocA: (int)locA fromLocB: (int)locB length: (int)lenB
{
	UKIntsEqual(locA, anEdit.range_in_a.location);
	UKIntsEqual(0, anEdit.range_in_a.length);
	UKIntsEqual(locB, anEdit.range_in_b.location);
	UKIntsEqual(lenB, anEdit.range_in_b.length);
	UKTrue(difftype_insertion == anEdit.type);
}

- (void) checkEdit: (diffedit_t)anEdit isModifyFromLocA: (int)locA length: (int)lenA toLocB: (int)locB length: (int) lenB
{
	UKIntsEqual(locA, anEdit.range_in_a.location);
	UKIntsEqual(lenA, anEdit.range_in_a.length);
	UKIntsEqual(locB, anEdit.range_in_b.location);
	UKIntsEqual(lenB, anEdit.range_in_b.length);
	UKTrue(difftype_modification == anEdit.type);
}

- (void) testBasic
{
	const char *array1 = "abcdefg";
	const char *array2 = "achidxyzg";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(7, diff_editcount(diff));

	[self checkEdit: diff_edit_at_index(diff, 0) isCopyFromLocA:0 length:1 toLocB:0];   // copy 'a'
	[self checkEdit: diff_edit_at_index(diff, 1) isDeleteFromLocA:1 length:1];          // delete 'b'
	[self checkEdit: diff_edit_at_index(diff, 2) isCopyFromLocA:2 length:1 toLocB:1];   // copy 'c'
	[self checkEdit: diff_edit_at_index(diff, 3) isInsertAtLocA:3 fromLocB:2 length:2]; // insert 'hi'
	[self checkEdit: diff_edit_at_index(diff, 4) isCopyFromLocA:3 length:1 toLocB:4];   // copy 'd'
	[self checkEdit: diff_edit_at_index(diff, 5) isModifyFromLocA:4 length:2 toLocB:5 length:3]; // modify 'ef' to 'xyz'
	[self checkEdit: diff_edit_at_index(diff, 6) isCopyFromLocA:6 length:1 toLocB:8];   // copy 'g'
}

@end
