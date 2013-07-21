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
	
	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
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
	//   \-document2 <<persistent root>>
	
	
	// Now make some changes
		
	[document2 setValue: @"My Shopping List" forProperty: @"label"]; [ctx commit];
	/* undo on workspace track, doc2 track: undo the last commit. */
	
	[document1 setValue: @"My Contacts" forProperty: @"label"]; [ctx commit];
	/* undo on workspace track, doc1 track: undo the last commit. */
	
	[leaf2 setValue: @"Tomatoes" forProperty: @"label"]; [ctx commit];
	
	[group2 addObject: leaf2]; [ctx commit];
	
	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
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
	//   \-document2 <<persistent root>>
	
	
	/**
	 * this is a move of embedded obejct tree
	 * implemented as copy + delete source
	 */
	[document2 addObject: group2]; [ctx commit]; // doc 1 and doc 2
	
	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       \-leaf1	
	//  | 
	//   \-document2 <<persistent root>>
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          \-leaf2
	
	
	[group2	setValue: @"Groceries" forProperty: @"label"]; [ctx commit]; // doc2
	[group1 setValue: @"Work Contacts" forProperty: @"label"]; [ctx commit]; // doc1
	[leaf3 setValue: @"Wine" forProperty: @"label"]; [ctx commit]; // doc2
	[leaf1 setValue: @"Alice" forProperty: @"label"]; [ctx commit]; // doc1
	[leaf3 setValue: @"Red wine" forProperty: @"label"]; [ctx commit]; // doc2
	[leaf2 setValue: @"Cheese" forProperty: @"label"]; [ctx commit]; // doc2
	[leaf1 setValue: @"Alice (cell)" forProperty: @"label"]; [ctx commit]; // doc1
	
	// introduce some new objects
	
	COContainer *leaf4 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf5 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *leaf6 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[leaf4 setValue: @"Leaf 4" forProperty: @"label"]; [ctx commit];
	[leaf5 setValue: @"Leaf 5" forProperty: @"label"]; [ctx commit];
	[leaf6 setValue: @"Leaf 6" forProperty: @"label"]; [ctx commit];	
	
	// add them to the lists

	[group1 addObject: leaf4]; [ctx commit]; // doc1
	
	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2 <<persistent root>>
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          \-leaf2
	
	
	
	[group2 addObject: leaf5]; [ctx commit]; // doc2

	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2 <<persistent root>>
	//      |
	//       \-group2
	//          |
	//          |-leaf3
	//          |
	//          |-leaf2
	//          |
	//          \-leaf5
	
	
	
	[group2 addObject: leaf6]; [ctx commit]; // doc2

	// workspace <<persistent root>>
	//  |
	//  |--document1 <<persistent root>>
	//  |   |
	//  |   \-group1
	//  |       |
	//  |       |-leaf1	
	//  |       |
	//  |       \-leaf4
	//  | 
	//   \-document2 <<persistent root>>
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
	
	
	[leaf4 setValue: @"Carol" forProperty: @"label"]; [ctx commit]; // doc1
	[leaf5 setValue: @"Pizza" forProperty: @"label"]; [ctx commit]; // doc2
	[leaf6 setValue: @"Beer" forProperty: @"label"]; [ctx commit];	// doc2
	
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
	
	// NB. leaf3 was always in doc1
	UKObjectsEqual(@"Red wine", [leaf3 valueForProperty: @"label"]);
	[leaf3Track undo]; // selective undo in doc1 -> creates a new commit
	UKObjectsEqual(@"Wine", [leaf3 valueForProperty: @"label"]);
	[leaf3Track undo]; // selective undo in doc1 -> creates a new commit
	UKObjectsEqual(@"Leaf 3", [leaf3 valueForProperty: @"label"]);
	
	
	// Now try undoing changes made to Document 1, using doc1track. 
	// "It shouldn't affect leaf3 until seveal steps back in to the history." (2010)
	// wrong, actually, the first thing it will do is undo the selective undos made
	// on leaf3 (nov 2011)
	
	// -undo label:wine -> label:leaf3 on leaf3
	// -undo label:red wine -> label:wine on leaf3
	// -undo label:carol -> label:leaf 4 on leaf4
	// -undo add leaf4 to group1
	// -undo label:alice -> label:alice (cell) on leaf1
    // -undo label:group  1 -> label:work contacts on group1
	// -undo the deletion part of move group2 from doc1 to doc2

	// FIXME: continue
}
@end
