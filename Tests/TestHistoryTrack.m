#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestHistoryTrack : EditingContextTestCase <UKTest>
{
    COUndoStack *_workspaceStack;
    COUndoStack *_doc1Stack;
    COUndoStack *_doc2Stack;
}
@end

@implementation TestHistoryTrack

- (id)init
{
	SUPERINIT;

    ASSIGN(_workspaceStack, [[COUndoStackStore defaultStore] stackForName: @"workspace"]);
    ASSIGN(_doc1Stack, [[COUndoStackStore defaultStore] stackForName: @"doc1"]);
    ASSIGN(_doc2Stack, [[COUndoStackStore defaultStore] stackForName: @"doc2"]);

    [_workspaceStack clear];
    [_doc1Stack clear];
    [_doc2Stack clear];
    
	return self;
}

- (void)dealloc
{
    [_workspaceStack release];
    [_doc1Stack release];
    [_doc2Stack release];
	[super dealloc];
}

- (void)testBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *workspace = [persistentRoot rootObject];
	COContainer *document1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *group1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *leaf2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *group2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COContainer *leaf3 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	COContainer *document2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	// Set up the initial state
	
	[document1 setValue:@"Document 1" forProperty: kCOLabel];
	[group1 setValue:@"Group 1" forProperty: kCOLabel];
	[leaf1 setValue:@"Leaf 1" forProperty: kCOLabel];
	[leaf2 setValue:@"Leaf 2" forProperty: kCOLabel];
	[group2 setValue:@"Group 2" forProperty: kCOLabel];
	[leaf3 setValue:@"Leaf 3" forProperty: kCOLabel];
	[document2 setValue:@"Document 2" forProperty: kCOLabel];

	[workspace addObject: document1];
	[workspace addObject: document2];
	[document1 addObject: group1];
	[group1 addObject: leaf1];
	[group1 addObject: leaf2];	
	[document1 addObject: group2];	
	[group2 addObject: leaf3];
	
	[ctx commitWithUndoStack: _workspaceStack];
	
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
		
	[document2 setValue: @"My Shopping List" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	/* undo on workspace track, doc2 track: undo the last commit. */
	
	[document1 setValue: @"My Contacts" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	/* undo on workspace track, doc1 track: undo the last commit. */
	
	[leaf2 setValue: @"Tomatoes" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	
	[group2 addObject: leaf2]; [ctx commitWithUndoStack: _doc1Stack];
	
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
	
	
	[document2 addObject: group2]; [ctx commitWithUndoStack: _doc2Stack];
	
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
	
	
	[group2	setValue: @"Groceries" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	[group1 setValue: @"Work Contacts" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	[leaf3 setValue: @"Wine" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	[leaf1 setValue: @"Alice" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	[leaf3 setValue: @"Red wine" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	[leaf2 setValue: @"Cheese" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	[leaf1 setValue: @"Alice (cell)" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	
	// introduce some new objects
	
	COContainer *leaf4 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[leaf4 setValue: @"Leaf 4" forProperty: kCOLabel];
	
	// add them to the lists

	[group1 addObject: leaf4]; [ctx commitWithUndoStack: _doc1Stack];
	
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
	
    COContainer *leaf5 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
    [leaf5 setValue: @"Leaf 5" forProperty: kCOLabel];

	[group2 addObject: leaf5]; [ctx commitWithUndoStack: _doc2Stack];

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
		
    COContainer *leaf6 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
	[leaf6 setValue: @"Leaf 6" forProperty: kCOLabel];

	[group2 addObject: leaf6]; [ctx commitWithUndoStack: _doc2Stack];

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
	
	
	[leaf4 setValue: @"Carol" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc1Stack];
	[leaf5 setValue: @"Pizza" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	[leaf6 setValue: @"Beer" forProperty: kCOLabel]; [ctx commitWithUndoStack: _doc2Stack];
	
	UKFalse([ctx hasChanges]);
	
	// Now try undoing changes made to Document 1, using @"doc1" track.

	// first undo should change leaf4's label from "Carol" -> "Leaf 4"
	UKObjectsEqual(@"Carol", [leaf4 valueForProperty: kCOLabel]);
	[_doc1Stack undoWithEditingContext: ctx];
    UKObjectsEqual(@"Leaf 4", [leaf4 valueForProperty: kCOLabel]);
    
	// next undo should remove leaf4 from group1
    
    UKObjectsEqual(S(leaf1, leaf4), SA([group1 contentArray]));
	[_doc1Stack undoWithEditingContext: ctx];
	UKObjectsEqual(S(leaf1), SA([group1 contentArray]));

	// next undo should change leaf1's label from "Alice (cell)" -> "Alice"
    
	UKObjectsEqual(@"Alice (cell)", [leaf1 valueForProperty: kCOLabel]);
	[_doc1Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Alice", [leaf1 valueForProperty: kCOLabel]);

	// next undo should change leaf1's label from "Alice" -> "Leaf 1"
    
	UKObjectsEqual(@"Alice", [leaf1 valueForProperty: kCOLabel]);
	[_doc1Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Leaf 1", [leaf1 valueForProperty: kCOLabel]);

	// next undo should change group1's label from "Work Contacts" -> "Group 1"
    
	UKObjectsEqual(@"Work Contacts", [group1 valueForProperty: kCOLabel]);
	[_doc1Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Group 1", [group1 valueForProperty: kCOLabel]);
	
	// next undo should move leaf2 from group2 back to group1
    
	UKTrue([[group2 contentArray] containsObject: leaf2]);
	UKFalse([[group1 contentArray] containsObject: leaf2]);
	[_doc1Stack undoWithEditingContext: ctx];
	UKFalse([[group2 contentArray] containsObject: leaf2]);
	UKTrue([[group1 contentArray] containsObject: leaf2]);

    // next undo would change leaf2's label from "Tomatoes" -> "Leaf 2"
    // but we already changed it on doc2's track to "Cheese", so we can't undo
    
    UKFalse([_doc1Stack canUndoWithEditingContext: ctx]);
    
    // Undo some changes on doc2
    
	// next undo should change leaf6's label from "Beer" -> "Leaf 6"
    
	UKObjectsEqual(@"Beer", [leaf6 valueForProperty: kCOLabel]);
	[_doc2Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Leaf 6", [leaf6 valueForProperty: kCOLabel]);
    
	// next undo should change leaf5's label from "Pizza" -> "Leaf 5"
    
	UKObjectsEqual(@"Pizza", [leaf5 valueForProperty: kCOLabel]);
	[_doc2Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Leaf 5", [leaf5 valueForProperty: kCOLabel]);
    
    // next undo should remove leaf6 from group2.
    // Note that an undo on doc1's track already removed leaf2
    
    UKObjectsEqual(S(leaf3, leaf5, leaf6), SA([group2 contentArray]));
	[_doc2Stack undoWithEditingContext: ctx];
    UKObjectsEqual(S(leaf3, leaf5), SA([group2 contentArray]));
    
    // next undo should remove leaf5 from group2.
    
    UKObjectsEqual(S(leaf3, leaf5), SA([group2 contentArray]));
	[_doc2Stack undoWithEditingContext: ctx];
    UKObjectsEqual(S(leaf3), SA([group2 contentArray]));
    
	// next undo should change leaf2's label from "Cheese" -> "Tomatoes"
    
	UKObjectsEqual(@"Cheese", [leaf2 valueForProperty: kCOLabel]);
	[_doc2Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Tomatoes", [leaf2 valueForProperty: kCOLabel]);

    // This should enable undo on doc1's track to proceed.
    
    UKTrue([_doc1Stack canUndoWithEditingContext: ctx]);
    
    UKObjectsEqual(@"Tomatoes", [leaf2 valueForProperty: kCOLabel]);
	[_doc1Stack undoWithEditingContext: ctx];
	UKObjectsEqual(@"Leaf 2", [leaf2 valueForProperty: kCOLabel]);
}

@end
