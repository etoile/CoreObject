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

- (void) testMixed
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
	
	diff_free(diff);
}

- (void) testMixed2
{
	const char *array1 = "abc";
	const char *array2 = "xaybcz";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(5, diff_editcount(diff));

	[self checkEdit: diff_edit_at_index(diff, 0) isInsertAtLocA:0 fromLocB:0 length:1]; // insert 'x'
	[self checkEdit: diff_edit_at_index(diff, 1) isCopyFromLocA:0 length:1 toLocB:1];   // copy 'a'
	[self checkEdit: diff_edit_at_index(diff, 2) isInsertAtLocA:1 fromLocB:2 length:1]; // insert 'y'
	[self checkEdit: diff_edit_at_index(diff, 3) isCopyFromLocA:1 length:2 toLocB:3];   // copy 'bc'
	[self checkEdit: diff_edit_at_index(diff, 4) isInsertAtLocA:3 fromLocB:5 length:1]; // insert 'z'
	
	diff_free(diff);
}

- (void) testInsertAtStart
{
	const char *array1 = "a";
	const char *array2 = "ba";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(2, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isInsertAtLocA: 0 fromLocB: 0 length: 1]; // insert 'b'
	[self checkEdit: diff_edit_at_index(diff, 1) isCopyFromLocA: 0 length: 1 toLocB: 1];   // copy 'a'

	diff_free(diff);
}

- (void) testDeleteAtStart
{
	const char *array1 = "ba";
	const char *array2 = "a";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(2, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isDeleteFromLocA: 0 length: 1];           // delete 'b'
	[self checkEdit: diff_edit_at_index(diff, 1) isCopyFromLocA: 1 length: 1 toLocB: 0];   // copy 'a'

	diff_free(diff);
}

- (void) testInsertAtEnd
{
	const char *array1 = "a";
	const char *array2 = "ab";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(2, diff_editcount(diff));

	[self checkEdit: diff_edit_at_index(diff, 0) isCopyFromLocA: 0 length: 1 toLocB: 0];   // copy 'a'
	[self checkEdit: diff_edit_at_index(diff, 1) isInsertAtLocA: 1 fromLocB: 1 length: 1]; // insert 'b'

	diff_free(diff);
}

- (void) testDeleteAtEnd
{
	const char *array1 = "ab";
	const char *array2 = "a";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(2, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isCopyFromLocA: 0 length: 1 toLocB: 0];    // copy 'a'
	[self checkEdit: diff_edit_at_index(diff, 1) isDeleteFromLocA: 1 length: 1];           // delete 'b'

	diff_free(diff);
}

- (void) testReplaceAll
{
	const char *array1 = "x";
	const char *array2 = "y";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(1, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isModifyFromLocA: 0 length: 1 toLocB: 0 length: 1]; // modify 'x' to 'y'

	diff_free(diff);
}

- (void) testInsertAll
{
	const char *array1 = "";
	const char *array2 = "a";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(1, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isInsertAtLocA: 0 fromLocB: 0 length: 1]; // insert 'a'

	diff_free(diff);
}

- (void) testDeleteAll
{
	const char *array1 = "a";
	const char *array2 = "";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(1, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isDeleteFromLocA: 0 length: 1];           // delete 'a'

	diff_free(diff);
}

- (void) testEmpty
{
	diffresult_t *diff = diff_arrays(0, 0, arraycomparefn, NULL, NULL);
	UKIntsEqual(0, diff_editcount(diff));

	diff_free(diff);
}

- (void) testSame
{
	const char *array1 = "a";
	const char *array2 = "a";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(1, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isCopyFromLocA:0 length:1 toLocB:0];

	diff_free(diff);
}

- (void) testDeleteCopyAndInsert
{
	const char *array1 = "abijk";
	const char *array2 = "bjkl";
	
	diffresult_t *diff = diff_arrays(strlen(array1), strlen(array2), arraycomparefn, array1, array2);
	UKIntsEqual(5, diff_editcount(diff));
	
	[self checkEdit: diff_edit_at_index(diff, 0) isDeleteFromLocA:0 length:1];
	[self checkEdit: diff_edit_at_index(diff, 1) isCopyFromLocA:1 length:1 toLocB:0];
	[self checkEdit: diff_edit_at_index(diff, 2) isDeleteFromLocA:2 length:1];
	[self checkEdit: diff_edit_at_index(diff, 3) isCopyFromLocA:3 length:2 toLocB:1];
	[self checkEdit: diff_edit_at_index(diff, 4) isInsertAtLocA:5 fromLocB:3 length:1];
	
	diff_free(diff);
}

@end
