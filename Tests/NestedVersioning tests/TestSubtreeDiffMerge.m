#import "TestCommon.h"

@interface TestSubtreeDiffMerge : NSObject <UKTest>
{
}

@end

@implementation TestSubtreeDiffMerge

#if 0
- (void) testBasic
{
	COSubtree *t1 = [COSubtree subtree];
	COSubtree *t2 = [COSubtree subtree];	
	COSubtree *t3a = [COSubtree subtree];
	COSubtree *t3b = [COSubtree subtree];
	[t1 addTree: t2];
	[t2 addTree: t3a];
	[t2 addTree: t3b];
	
	
	// Create a copy and modify it.
	COSubtree *u1 = [[t1 copy] autorelease];
	
	UKObjectsEqual(u1, t1);
	
	COSubtree *u2 = [u1 subtreeWithUUID: [t2 UUID]];
	COSubtree *u3a = [u1 subtreeWithUUID: [t3a UUID]];
	
	[u2 removeSubtreeWithUUID: [t3b UUID]];
	
	COSubtree *u4 = [COSubtree subtree];
	[u3a addTree: u4];
	
	[u4 setPrimitiveValue: @"This node was added"
			 forAttribute: @"comment"
					 type: kCOTypeString];
	
	
	// Test creating a diff
	COSubtreeDiff *diff_t1_u1 = [COSubtreeDiff diffSubtree: t1 withSubtree: u1 sourceIdentifier: @"fixme"];
	
	//NSLog(@"diff_t1_u1: %@", diff_t1_u1);
	
	COSubtree *u1_generated_from_diff = [diff_t1_u1 subtreeWithDiffAppliedToSubtree: t1];
	
	UKObjectsEqual(u1, u1_generated_from_diff);
}

- (void) testDeleteAttribute
{
	COSubtree *t1 = [COSubtree subtree];
	COSubtree *t2 = [[t1 copy] autorelease];
	
	[t1 setPrimitiveValue: @"This node was added"
			 forAttribute: @"comment"
					 type: kCOTypeString];
		
	COSubtreeDiff *diff_t1_t2 = [COSubtreeDiff diffSubtree: t1 withSubtree: t2 sourceIdentifier: @"my source"];
	
	COSubtree *t2_generated_from_diff = [diff_t1_t2 subtreeWithDiffAppliedToSubtree: t1];
	
	UKObjectsEqual(t2, t2_generated_from_diff);
}

- (void)testSelectiveUndoOfGroupOperation
{
	COSubtree *doc = [COSubtree subtree];
	COSubtree *line1 = [COSubtree subtree];
	COSubtree *circle1 = [COSubtree subtree];
	COSubtree *square1 = [COSubtree subtree];
	COSubtree *image1 = [COSubtree subtree];

	[doc setValue: @"doc" forAttribute: @"name" type: kCOTypeString];		
	[line1 setValue: @"line1" forAttribute: @"name" type: kCOTypeString];	
	[circle1 setValue: @"circle1" forAttribute: @"name" type: kCOTypeString];
	[square1 setValue: @"square1" forAttribute: @"name" type: kCOTypeString];	
	[image1 setValue: @"image1" forAttribute: @"name" type: kCOTypeString];
	
	[doc setValue: A(line1, circle1, square1, image1)
	 forAttribute: @"contents"
			 type: kCOTypeCompositeReference | kCOTypeArray];

	// snapshot the state: (line1, circle1, square1, image1) into doc2
	COSubtree *doc2 = [[doc copy] autorelease];
	
	COSubtree *group1 = [COSubtree subtree];
	[group1 setValue: @"group1" forAttribute: @"name" type: kCOTypeString];
	doc addObject: group1 toOrderedAttribute: @"contents" atIndex: 1 type: [kCOTypeCompositeReference | kCOTypeArray];
	[group1 addTree: circle1];
	[group1 addTree: square1];
	
	// snapshot the state:  (line1, group1=(circle1, square1), image1) into ctx3
	COSubtree *doc3 = [[doc copy] autorelease];
	
	COSubtree *triangle1 = [COSubtree subtree];
	[triangle1 setValue: @"triangle1" forAttribute: @"name" type: kCOTypeString];
	doc addObject: triangle1 toOrderedAttribute: @"contents" atIndex: 0 type: [kCOTypeCompositeReference | kCOTypeArray];
	
	
	// doc state:  (triangl1, line1, group1=(circle1, square1), image1)
	
	/**
	 
	 doc2->doc3: -replace doc.contents[1:2] (circle, square) with group1.
	             -set group1.contents to { circle, square } (unordered)
	 
	 doc3->doc2: -replace doc.contents[1:1] (group1) with (circle1, square1)
	              (group1 becomes disconnected from the subtree)
	*/
	
	
	// ------------
	
	
	// Calculate diffs
	
	COSubtreeDiff *diff_doc3_vs_doc2 = [COSubtreeDiff diffSubtree: doc3 withSubtree: doc2 sourceIdentifier: @"fixme"];
	COSubtreeDiff *diff_doc3_vs_doc = [COSubtreeDiff diffSubtree: doc3 withSubtree: doc sourceIdentifier: @"fixme"];
	
	// Sanity check that the diffs work
	
	UKObjectsEqual(doc, [diff_doc3_vs_doc subtreeWithDiffAppliedToSubtree: doc3]);
	UKObjectsEqual(doc2, [diff_doc3_vs_doc2 subtreeWithDiffAppliedToSubtree: doc3]);
	
	COSubtreeDiff *diff_merged = [diff_doc3_vs_doc2 subtreeDiffByMergingWithDiff: diff_doc3_vs_doc];
	
	COSubtree *merged = [diff_merged subtreeWithDiffAppliedToSubtree: doc3];
	
	UKFalse([diff_merged hasConflicts]);
	
	UKObjectsEqual(A(triangle1, line1, circle1, square1, image1), [merged valueForAttribute: @"contents"]);
}

/**
 * This test creates a conflict where 
 */
- (void)testTreeConflict
{
	COSubtree *docO, *docA, *docB, *docMergeResolved;

	COSubtree *doc = [COSubtree subtree];
	COSubtree *group1 = [COSubtree subtree];
	COSubtree *group2 = [COSubtree subtree];
	COSubtree *shape1 = [COSubtree subtree];

	// 1. Setup docO, docA, docB
	{		
		[doc setValue: @"doc" forAttribute: @"name" type: kCOTypeString];		
		[group1 setValue: @"group1" forAttribute: @"name" type: kCOTypeString];	
		[group2 setValue: @"group2" forAttribute: @"name" type: kCOTypeString];
		[shape1 setValue: @"shape1" forAttribute: @"name" type: kCOTypeString];	
		
		[doc addTree: shape1];
		
		docO = [[doc copy] autorelease];    // doc0 -> shape1
		
		[doc addTree: group1];
		[group1 addTree: shape1];
		
		docA = [[doc copy] autorelease];   // docA -> group1 -> shape1
		
		[doc addTree: group2];
		[group2 addTree: shape1];
		[doc removeSubtree: group1];
		
		docB = [[doc copy] autorelease];   // docB -> group2 -> shape1
		
		[doc addTree: group1];		
		[group1 addTree: shape1];
		[group2 removeValueForAttribute: @"contents"]; // FIXME: Hack to make equality test later work

		docMergeResolved = [[doc copy] autorelease];   // docMergeResolved -> ((group1 -> shape1), group2)
	}
	
	COSubtreeDiff *diff_docO_vs_docA = [COSubtreeDiff diffSubtree: docO withSubtree: docA sourceIdentifier: @"OA"];
	COSubtreeDiff *diff_docO_vs_docB = [COSubtreeDiff diffSubtree: docO withSubtree: docB sourceIdentifier: @"OB"];
	
	// Sanity check that the diffs work
	
	UKObjectsEqual(docA, [diff_docO_vs_docA subtreeWithDiffAppliedToSubtree: docA]);
	UKObjectsEqual(docB, [diff_docO_vs_docB subtreeWithDiffAppliedToSubtree: docB]);
	
	COSubtreeDiff *diff_merged = [diff_docO_vs_docA subtreeDiffByMergingWithDiff: diff_docO_vs_docB];
	
	// merged: doc -> ((group1 -> shape1), (group2 -> shape1))
	// there is one conflict: shape1 is being inserted in two places.
		
	UKTrue([diff_merged hasConflicts]);	
	UKIntsEqual(1, [[diff_merged conflicts] count]);
	
	COSubtreeConflict *conflict = [[diff_merged conflicts] anyObject];
	
	UKIntsEqual(2, [[conflict allEdits] count]);
	UKIntsEqual(1, [[conflict editsForSourceIdentifier: @"OA"] count]);
	UKIntsEqual(1, [[conflict editsForSourceIdentifier: @"OB"] count]);
	
	COSubtreeEdit *OAConflictingEdit = [[conflict editsForSourceIdentifier: @"OA"] anyObject];
	COSubtreeEdit *OBConflictingEdit = [[conflict editsForSourceIdentifier: @"OB"] anyObject];
	
	COSubtreeEdit *OAConflictingExpected = [[[COSetAttribute alloc] initWithUUID: [group1 UUID]
																	   attribute: @"contents"
																sourceIdentifier: @"OA"
																			type: kCOTypeCompositeReference | kCOTypeSet
																		   value: S([shape1 UUID])] autorelease];
	
	COSubtreeEdit *OBConflictingExpected = [[[COSetAttribute alloc] initWithUUID: [group2 UUID]
																	   attribute: @"contents"
																sourceIdentifier: @"OB"
																			type: kCOTypeCompositeReference | kCOTypeSet
																		   value: S([shape1 UUID])] autorelease];
	
	UKObjectsEqual(OAConflictingExpected, OAConflictingEdit);
	UKObjectsEqual(OBConflictingExpected, OBConflictingEdit);
	
	
	// now remove the conflict
	
	
	[diff_merged removeConflict: conflict];
	
	UKFalse([diff_merged hasConflicts]);	
	UKIntsEqual(0, [[diff_merged conflicts] count]);

	[diff_merged addEdit: OAConflictingEdit];
	
	UKFalse([diff_merged hasConflicts]);	
	UKIntsEqual(0, [[diff_merged conflicts] count]);

	
	COSubtree *actualMergeResolved = [diff_merged subtreeWithDiffAppliedToSubtree: docO];
	
	COSubtree *group2lhs = [docMergeResolved subtreeWithUUID: [group2 UUID]];
	COSubtree *group2rhs = [actualMergeResolved subtreeWithUUID: [group2 UUID]];
	
	// FIXME: refine semantics for a COItem having an empty set vs no set.
	UKObjectsEqual(group2lhs, group2rhs);
	UKObjectsEqual(docMergeResolved, actualMergeResolved);
}

- (void) testMergingEqualEdits
{
	COSubtree *t2 = [COSubtree subtree];
	COSubtree *t1 = [[t2 copy] autorelease];
	COSubtree *t3 = [[t2 copy] autorelease];
		
	[t2 setPrimitiveValue: @"This node was added"
			 forAttribute: @"comment"
					 type: kCOTypeString];
	[t3 setPrimitiveValue: @"This node was added"
			 forAttribute: @"comment"
					 type: kCOTypeString];
	
	UKObjectsEqual(t2, t3);
	
	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: t1 withSubtree: t2 sourceIdentifier: @"diff12"];
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: t1 withSubtree: t3 sourceIdentifier: @"diff13"];
	
	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKFalse([merged hasConflicts]);
	UKObjectsEqual(t2, [merged subtreeWithDiffAppliedToSubtree: t1]);
	UKObjectsEqual(t3, [merged subtreeWithDiffAppliedToSubtree: t1]);
}

- (void) testMergingSetValue
{
	COSubtree *t2 = [COSubtree subtree];
	COSubtree *t1 = [[t2 copy] autorelease];
	COSubtree *t3 = [[t2 copy] autorelease];
	
	[t2 setPrimitiveValue: @"abc"
			 forAttribute: @"string"
					 type: kCOTypeString];
	[t3 setPrimitiveValue: @"def"
			 forAttribute: @"string"
					 type: kCOTypeString];

	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: t1 withSubtree: t2 sourceIdentifier: @"diff12"];
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: t1 withSubtree: t3 sourceIdentifier: @"diff13"];
	UKObjectsEqual(t2, [diff12 subtreeWithDiffAppliedToSubtree: t1]);
	UKObjectsEqual(t3, [diff13 subtreeWithDiffAppliedToSubtree: t1]);
	
	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKTrue([merged hasConflicts]);
}


- (NSSet *) insertionSetForUUID: (COUUID *)aUUID attribute: (NSString *)attribute diff: (COSubtreeDiff *)aDiff sourceID: (id)source
{
	NSMutableSet *result = [NSMutableSet set];
	for (COSubtreeEdit *edit in [aDiff editsForUUID: aUUID attribute: attribute])
	{
		if ([edit isMemberOfClass: [COSetInsertion class]]
			&& (source == nil || [[edit sourceIdentifier] isEqual: source]))
		{
			[result addObject: [(COSetInsertion *)edit object]];
		}
	}
	return result;
}

- (NSSet *) deletionSetForUUID: (COUUID *)aUUID attribute: (NSString *)attribute diff: (COSubtreeDiff *)aDiff sourceID: (id)source
{
	NSMutableSet *result = [NSMutableSet set];
	for (COSubtreeEdit *edit in [aDiff editsForUUID: aUUID attribute: attribute])
	{
		if ([edit isMemberOfClass: [COSetDeletion class]]
			&& (source == nil || [[edit sourceIdentifier] isEqual: source]))
		{
			[result addObject: [(COSetDeletion *)edit object]];
		}
	}
	return result;
}

- (void) testUnorderedMultivaluesPropertyDiffMerge
{
	COSubtree *doc1 = [COSubtree subtree];	
	COSubtree *doc2 = [[doc1 copy] autorelease];
	COSubtree *doc3 = [[doc1 copy] autorelease];;

	NSSet *set2 = S(@"A", @"b", @"d", @"zoo", @"e");
	NSSet *set1 = S(@"a", @"b", @"c", @"d", @"e");
	NSSet *set3 = S(@"A", @"b", @"c", @"e", @"foo");

	doc2 setValue: set2 forAttribute: @"set" type: [kCOTypeString | kCOTypeSet];
	doc1 setValue: set1 forAttribute: @"set" type: [kCOTypeString | kCOTypeSet];
	doc3 setValue: set3 forAttribute: @"set" type: [kCOTypeString | kCOTypeSet];

	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc2 sourceIdentifier: @"diff12"];
	
	UKObjectsEqual(S(@"A", @"zoo"), [self insertionSetForUUID: [doc1 UUID] attribute: @"set" diff: diff12 sourceID: nil]);
	UKObjectsEqual(S(@"a", @"c"), [self deletionSetForUUID: [doc1 UUID] attribute: @"set" diff: diff12 sourceID: nil]);
	UKObjectsEqual(set2, [[diff12 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"set"]);
	
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc3 sourceIdentifier: @"diff13"];
	UKObjectsEqual(S(@"A", @"foo"), [self insertionSetForUUID: [doc1 UUID] attribute: @"set" diff: diff13 sourceID: nil]);
	UKObjectsEqual(S(@"a", @"d"), [self deletionSetForUUID: [doc1 UUID] attribute: @"set" diff: diff13 sourceID: nil]);
	UKObjectsEqual(set3, [[diff13 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"set"]);

	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKObjectsEqual(S(@"A", @"foo", @"zoo"), [self insertionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: nil]);
	UKObjectsEqual(S(@"a", @"d", @"c"), [self deletionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: nil]);
	UKObjectsEqual(S(@"A", @"b", @"zoo", @"e", @"foo"), [[merged subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"set"]);

	UKObjectsEqual(S(@"A", @"zoo"), [self insertionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: @"diff12"]);
	UKObjectsEqual(S(@"a", @"c"), [self deletionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: @"diff12"]);
	UKObjectsEqual(S(@"A", @"foo"), [self insertionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: @"diff13"]);
	UKObjectsEqual(S(@"a", @"d"), [self deletionSetForUUID: [doc1 UUID] attribute: @"set" diff: merged sourceID: @"diff13"]);	
}


#pragma mark sequence diff merged

- (void) testBasicSequenceDiff
{
	COSubtree *doc2 = [COSubtree subtree];	
	COSubtree *doc1 = [[doc2 copy] autorelease];
	COSubtree *doc3 = [[doc2 copy] autorelease];
	
	NSArray *array2 = A(@"A", @"b", @"d", @"zoo", @"e");
	NSArray *array1 = A(@"a", @"b", @"c", @"d", @"e");
	NSArray *array3 = A(@"A", @"b", @"c", @"e", @"foo");
	
	doc2 setValue: array2 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc1 setValue: array1 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc3 setValue: array3 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];

	
	/**
	 * modify a->A, remove c, insert 'zoo' after d
	 */
	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc2 sourceIdentifier: @"diff12"];
	
	/**
	 * modify a->A, remove d, insert 'foo' after e
	 */
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc3 sourceIdentifier: @"diff13"];
	
	UKObjectsEqual(array2, [[diff12 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	UKObjectsEqual(array3, [[diff13 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	
	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKFalse([merged hasConflicts]);
	
	// Expected: {a->A nonconflicting}, remove c, remove d,  insert 'zoo', insert 'foo'
	
	UKObjectsEqual(A(@"A", @"b", @"zoo", @"e", @"foo"), [[merged subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	
	/*
	// Examine the a->A change group
	
	COOverlappingSequenceEditGroup *edit1 = (COOverlappingSequenceEditGroup *)[[merged operations] objectAtIndex: 0];
	
	UKObjectKindOf(edit1, COOverlappingSequenceEditGroup);
	UKIntsEqual(2, [[edit1 allEdits] count]);
	
	// Examine the a->A change from diff12
	
	NSArray *edit1diff12Array = [edit1 editsForSourceIdentifier: @"diff12"];
	UKIntsEqual(1, [edit1diff12Array count]);
	
	COSequenceModification *edit1diff12 = [edit1diff12Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff12, COSequenceModification);
	UKObjectsEqual(A(@"A"), [edit1diff12 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(0, 1), [edit1diff12 range]));
	UKObjectsEqual(@"diff12", [edit1diff12 sourceIdentifier]);
	
	// Examine the a->A change from diff13
	
	NSArray *edit1diff13Array = [edit1 editsForSourceIdentifier: @"diff13"];
	UKIntsEqual(1, [edit1diff13Array count]);
	
	COSequenceModification *edit1diff13 = [edit1diff13Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff13, COSequenceModification);
	UKObjectsEqual(A(@"A"), [edit1diff13 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(0, 1), [edit1diff13 range]));
	UKObjectsEqual(@"diff13", [edit1diff13 sourceIdentifier]);
	
	UKObjectsNotEqual(edit1diff12, edit1diff13); // because their sourceIdentifiers are different
	UKTrue([edit1diff12 isEqualIgnoringSourceIdentifier: edit1diff13]);	*/
}


- (void) testSimpleSequenceConflict
{
	COSubtree *doc2 = [COSubtree subtree];	
	COSubtree *doc1 = [[doc2 copy] autorelease];
	COSubtree *doc3 = [[doc2 copy] autorelease];
	
	NSArray *array2 = A(@"c");
	NSArray *array1 = A(@"a");
	NSArray *array3 = A(@"b");
	
	doc2 setValue: array2 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc1 setValue: array1 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc3 setValue: array3 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	
	
	//
	// modify a->b
	//
	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc2 sourceIdentifier: @"diff12"];
	
	//
	// modify a->c
	//
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc3 sourceIdentifier: @"diff13"];
	
	UKObjectsEqual(array2, [[diff12 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	UKObjectsEqual(array3, [[diff13 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	
	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKTrue([merged hasConflicts]);
	
	/*NSArray *array2 = A(@"c");
	NSArray *array1 = A(@"a");
	NSArray *array3 = A(@"b");
	
	//
	//modify a->c
	//
	COArrayDiff *diff12 = [[COArrayDiff alloc] initWithFirstArray: array1 secondArray: array2 sourceIdentifier: @"diff12"];
	
	//
	//modify a->b
	//
	COArrayDiff *diff13 = [[COArrayDiff alloc] initWithFirstArray: array1 secondArray: array3 sourceIdentifier: @"diff13"];
	
	COArrayDiff *merged = (COArrayDiff *)[diff12 sequenceDiffByMergingWithDiff: diff13];
	UKTrue([merged hasConflicts]);
	
	// Examine the {a->c, a->b} change group
	
	COOverlappingSequenceEditGroup *edit1 = (COOverlappingSequenceEditGroup *)[[merged operations] objectAtIndex: 0];
	
	UKObjectKindOf(edit1, COOverlappingSequenceEditGroup);
	UKTrue([edit1 hasConflicts]);
	UKIntsEqual(2, [[edit1 allEdits] count]);
	
	// Examine the a->c change from diff12
	
	NSArray *edit1diff12Array = [edit1 editsForSourceIdentifier: @"diff12"];
	UKIntsEqual(1, [edit1diff12Array count]);
	
	COSequenceModification *edit1diff12 = [edit1diff12Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff12, COSequenceModification);
	UKObjectsEqual(A(@"c"), [edit1diff12 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(0, 1), [edit1diff12 range]));
	UKObjectsEqual(@"diff12", [edit1diff12 sourceIdentifier]);
	
	// Examine the a->b change from diff13
	
	NSArray *edit1diff13Array = [edit1 editsForSourceIdentifier: @"diff13"];
	UKIntsEqual(1, [edit1diff13Array count]);
	
	COSequenceModification *edit1diff13 = [edit1diff13Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff13, COSequenceModification);
	UKObjectsEqual(A(@"b"), [edit1diff13 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(0, 1), [edit1diff13 range]));
	UKObjectsEqual(@"diff13", [edit1diff13 sourceIdentifier]);
	
	UKFalse([edit1diff12 isEqualIgnoringSourceIdentifier: edit1diff13]);*/
}


- (void) testLessSimpleConflict
{
	/*
	 
	 in this example, <delete 'b'-'d'> will conflict with two changes, {b->X, d->Z}
	 
	 */
	
	COSubtree *doc2 = [COSubtree subtree];	
	COSubtree *doc1 = [[doc2 copy] autorelease];
	COSubtree *doc3 = [[doc2 copy] autorelease];	
	
	NSArray *array2 = A(@"a",                   @"e");
	NSArray *array1 = A(@"a", @"b", @"c", @"d", @"e");
	NSArray *array3 = A(@"a", @"X", @"c", @"Z", @"e");
	
	doc2 setValue: array2 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc1 setValue: array1 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	doc3 setValue: array3 forAttribute: @"array" type: [kCOTypeString | kCOTypeArray];
	
	
	COSubtreeDiff *diff12 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc2 sourceIdentifier: @"diff12"];
	COSubtreeDiff *diff13 = [COSubtreeDiff diffSubtree: doc1 withSubtree:doc3 sourceIdentifier: @"diff13"];	
	UKObjectsEqual(array2, [[diff12 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	UKObjectsEqual(array3, [[diff13 subtreeWithDiffAppliedToSubtree: doc1] valueForAttribute: @"array"]);
	
	COSubtreeDiff *merged = [diff12 subtreeDiffByMergingWithDiff: diff13];
	UKTrue([merged hasConflicts]);
	
	/*
	UKIntsEqual(1, [[merged operations] count]);
	
	// Examine the (single) change group
	
	COOverlappingSequenceEditGroup *edit1 = (COOverlappingSequenceEditGroup *)[[merged operations] objectAtIndex: 0];
	
	UKObjectKindOf(edit1, COOverlappingSequenceEditGroup);
	UKTrue([edit1 hasConflicts]);
	
	// Examine the <delete 'b'-'d'> change from diff12
	
	NSArray *edit1diff12Array = [edit1 editsForSourceIdentifier: @"diff12"];
	UKIntsEqual(1, [edit1diff12Array count]);
	
	COSequenceDeletion *edit1diff12 = [edit1diff12Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff12, COSequenceDeletion);
	UKTrue(NSEqualRanges(NSMakeRange(1, 3), [edit1diff12 range]));
	UKObjectsEqual(@"diff12", [edit1diff12 sourceIdentifier]);
	
	// Examine the {b->X, d->Z} change from diff13
	
	NSArray *edit1diff13Array = [edit1 editsForSourceIdentifier: @"diff13"];
	UKIntsEqual(2, [edit1diff13Array count]);
	
	COSequenceModification *edit1diff13_1 = [edit1diff13Array objectAtIndex: 0];
	UKObjectKindOf(edit1diff13_1, COSequenceModification);
	UKObjectsEqual(A(@"X"), [edit1diff13_1 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(1, 1), [edit1diff13_1 range]));
	UKObjectsEqual(@"diff13", [edit1diff13_1 sourceIdentifier]);
	
	COSequenceModification *edit1diff13_2 = [edit1diff13Array objectAtIndex: 1];
	UKObjectKindOf(edit1diff13_2, COSequenceModification);
	UKObjectsEqual(A(@"Z"), [edit1diff13_2 insertedObject]);
	UKTrue(NSEqualRanges(NSMakeRange(3, 1), [edit1diff13_2 range]));
	UKObjectsEqual(@"diff13", [edit1diff13_2 sourceIdentifier]);
	 */
}
#endif

@end
