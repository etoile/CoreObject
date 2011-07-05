#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COContainer.h"
#import "COCollection.h"
#import "TestCommon.h"

@interface TestHistoryTrack : NSObject <UKTest>
{
}
@end

@implementation TestHistoryTrack

- (void)testBasic
{
	COEditingContext *ctx = NewContext();
	
	COContainer *workspace = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *document1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *group1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *group2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *leaf3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	COContainer *document2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	// Set up the initial state
	
	[document1 setValue:@"Document 1" forProperty: @"label"];
	[group1 setValue:@"Group 1" forProperty: @"label"];
	[leaf1 setValue:@"Leaf 1" forProperty: @"label"];
	[leaf2 setValue:@"Leaf 2" forProperty: @"label"];
	[group2 setValue:@"Group 2" forProperty: @"label"];
	[leaf3 setValue:@"Leaf 3" forProperty: @"label"];
	[document2 setValue:@"Document 2" forProperty: @"label"];

	[workspace addObject: document1];
	[workspace addObject: document2];
	[document1 addObject: group1];
	[group1 addObject: leaf1];
	[group1 addObject: leaf2];	
	[document1 addObject: group2];	
	[group2 addObject: leaf3];
	
	[ctx commit];
	
	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   |-group1
	//  |   |   |
	//  |   |   |-leaf1	
	//  |   |   |
	//  |   |   \-leaf2
	//  |   |
	//  |    \-group2
	//  |       |
	//  |       \-leaf3
	//  | 
	//   \-document2	
	
	
	// Now make some changes
		
	[document2 setValue: @"My Shopping List" forProperty: @"label"]; [ctx commit];
	/* undo on workspace track, doc2 track: undo the last commit. */
	
	[document1 setValue: @"My Contacts" forProperty: @"label"]; [ctx commit];
	/* undo on workspace track, doc1 track: undo the last commit. */
	
	[leaf2 setValue: @"Tomatoes" forProperty: @"label"]; [ctx commit];
	
	[group2 addObject: leaf2]; [ctx commit];
	
	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   |-group1
	//  |   |   |
	//  |   |   \-leaf1	
	//  |   |
	//  |    \-group2
	//  |       |
	//  |       |-leaf3
	//  |       |
	//  |       \-leaf2
	//  | 
	//   \-document2
	
	
	[document2 addObject: group2]; [ctx commit];
	
	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       \-leaf1	
	//  | 
	//   \-document2
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          \-leaf2
	
	
	[group2	setValue: @"Groceries" forProperty: @"label"]; [ctx commit];
	[group1 setValue: @"Work Contacts" forProperty: @"label"]; [ctx commit];
	[leaf3 setValue: @"Wine" forProperty: @"label"]; [ctx commit];
	[leaf1 setValue: @"Alice" forProperty: @"label"]; [ctx commit];
	[leaf3 setValue: @"Red wine" forProperty: @"label"]; [ctx commit];
	[leaf2 setValue: @"Cheese" forProperty: @"label"]; [ctx commit];
	[leaf1 setValue: @"Alice (cell)" forProperty: @"label"]; [ctx commit];
	
	// introduce some new objects
	
	COContainer *leaf4 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf5 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *leaf6 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[leaf4 setValue: @"Leaf 4" forProperty: @"label"]; [ctx commit];
	[leaf5 setValue: @"Leaf 5" forProperty: @"label"]; [ctx commit];
	[leaf6 setValue: @"Leaf 6" forProperty: @"label"]; [ctx commit];	
	
	// add them to the lists

	[group1 addObject: leaf4]; [ctx commit];
	
	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          \-leaf2
	
	
	
	[group2 addObject: leaf5]; [ctx commit];

	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          |-leaf2
	//          |
	//          \-leaf5
	
	
	
	[group2 addObject: leaf6]; [ctx commit];

	// workspace
	//  |
	//  |--document1
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          |-leaf2
	//          |
	//          |-leaf5	
	//          |
	//          \-leaf6
	
	
	[leaf4 setValue: @"Carol" forProperty: @"label"]; [ctx commit];
	[leaf5 setValue: @"Pizza" forProperty: @"label"]; [ctx commit];
	[leaf6 setValue: @"Beer" forProperty: @"label"]; [ctx commit];	
	
	UKFalse([ctx hasChanges]);
	
	// Finally, create some history tracks.
	
	
	COHistoryTrack *workspaceTrack = [[COHistoryTrack alloc] initTrackWithObject: workspace containedObjects: YES];
	COHistoryTrack *doc1Track = [[COHistoryTrack alloc] initTrackWithObject: document1 containedObjects: YES];
	COHistoryTrack *doc2Track = [[COHistoryTrack alloc] initTrackWithObject: document2 containedObjects: YES];
	COHistoryTrack *leaf3Track = [[COHistoryTrack alloc] initTrackWithObject: leaf3 containedObjects: NO];
	
	UKNotNil(workspaceTrack);
	UKNotNil(doc1Track);
	UKNotNil(doc2Track);
	UKNotNil(leaf3Track);
	
	
	// Start with an easy test
	
	
	UKObjectsEqual(@"Red wine", [leaf3 valueForProperty: @"label"]);
	[leaf3Track undo];
	UKObjectsEqual(@"Wine", [leaf3 valueForProperty: @"label"]);
	[leaf3Track undo];
	UKObjectsEqual(@"Leaf 3", [leaf3 valueForProperty: @"label"]);
	//UKObjectsEqual(S([leaf3 UUID]), [ctx changedObjectUUIDs]); // Ensure that no other objects were changed by the history track
	
	
	// Now try undoing changes made to Document 1, using doc1track. It shouldn't 
	// affect leaf3 until seveal steps back in to the history.
	
	
	// first undo should change leaf4's label from "Carol" -> "Leaf 4"
	UKObjectsEqual(@"Carol", [leaf4 valueForProperty: @"label"]);
	[doc1Track undo]; 
	UKObjectsEqual(@"Leaf 4", [leaf4 valueForProperty: @"label"]);
	//UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID]), [ctx changedObjectUUIDs]);
	
	// next undo should remove leaf4 from group1
	UKObjectsEqual(S([leaf1 UUID], [leaf4 UUID]), [[[NSSet setWithArray: [group1 contentArray]] mappedCollection] UUID]);
	[doc1Track undo]; 
	UKObjectsEqual(S([leaf1 UUID]), [[[NSSet setWithArray: [group1 contentArray]] mappedCollection] UUID]);	
	//UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID]), [ctx changedObjectUUIDs]);

	// FIXME: Undo doesn't work in the code below.

/*
	// next undo should change leaf1's label from "Alice (cell)" -> "Alice"
	UKObjectsEqual(@"Alice (cell)", [leaf1 valueForProperty: @"label"]);
	[doc1Track undo]; 
	UKObjectsEqual(@"Alice", [leaf1 valueForProperty: @"label"]);
	//UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID]), [ctx changedObjectUUIDs]);
	
	// next undo should change group1's label from "Work Contacts" -> "Group 1"
	UKObjectsEqual(@"Work Contacts", [group1 valueForProperty: @"label"]);
	[doc1Track undo]; 
	UKObjectsEqual(@"Group 1", [group1 valueForProperty: @"label"]);
	//UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID]), [ctx changedObjectUUIDs]);
	
	// next undo should move group2 from document 2 back to document 1
	UKTrue([[document2 contentArray] containsObject: group2]);
	UKFalse([[document1 contentArray] containsObject: group2]);
	UKObjectsSame(document2, [group2 valueForProperty: @"parentContainer"]);
	[doc1Track undo]; 
	UKFalse([[document2 contentArray] containsObject: group2]);
	UKTrue([[document1 contentArray] containsObject: group2]);
	UKObjectsSame(document1, [group2 valueForProperty: @"parentContainer"]);
	//UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID], [document2 UUID], [group2 UUID], [document1 UUID]), [ctx changedObjectUUIDs]);
*/	
	// FIXME: After group 2 is moved back to doc1, the next undo will actually
	// be the newest changes in group 2 (e.g. Leaf 6 -> Beer, and Leaf 5 -> Pizza)
	// So the following tests need to be rewritten.
	
/*	
	// next undo should move leaf2 ("Tomatoes") from group 2 to group 1
	UKTrue([[group2 contentArray] containsObject: leaf2]);
	UKFalse([[group1 contentArray] containsObject: leaf2]);
	UKObjectsSame(group2, [leaf2 valueForProperty: @"parentContainer"]);
	[doc1Track undo]; 
	UKFalse([[group2 contentArray] containsObject: leaf2]);
	UKTrue([[group1 contentArray] containsObject: leaf2]);
	UKObjectsSame(group1, [leaf2 valueForProperty: @"parentContainer"]);
	UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID], [document2 UUID], [group2 UUID], [document1 UUID], [leaf2 UUID]), [ctx changedObjectUUIDs]);
	
	// next undo should rename leaf2 "Tomatoes" -> "Leaf 2"
	UKObjectsEqual(@"Tomatoes", [leaf2 valueForProperty: @"label"]);
	[doc1Track undo]; 
	UKObjectsEqual(@"Leaf 2", [leaf2 valueForProperty: @"label"]);
	UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID], [document2 UUID], [group2 UUID], [document1 UUID], [leaf2 UUID]), [ctx changedObjectUUIDs]);

	// next undo should rename document 1 "My Contacts" -> "Document 1"
	UKObjectsEqual(@"My Contacts", [document1 valueForProperty: @"label"]);
	[doc1Track undo]; 
	UKObjectsEqual(@"Document 1", [document1 valueForProperty: @"label"]);
	UKObjectsEqual(S([leaf3 UUID], [leaf4 UUID], [group1 UUID], [leaf1 UUID], [document2 UUID], [group2 UUID], [document1 UUID], [leaf2 UUID]), [ctx changedObjectUUIDs]);
	
	// FIXME: The next undo would undo the initial commit of Document 1.
	// Need to decide what happens if you try to undo it
	
	
	
	//
	// Now we will test a more complicated scenario: performing undo/redo on
	// document 2.
	//
	
	
	UKObjectsEqual(@"Groceries", [group2 valueForProperty: @"label"]); // Verify that the state of document2 wasn't changed (other than moving group2 back to document 1)
	[doc2Track undo];
	// FIXME
*/
	
	[workspaceTrack release];
	[doc1Track release];
	[doc2Track release];
	TearDownContext(ctx);
}
@end
