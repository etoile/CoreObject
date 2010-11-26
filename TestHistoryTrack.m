#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COGroup.h"
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
	
	COGroup *workspace = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *document1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *group1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *leaf1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *leaf2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COGroup *group2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COGroup *leaf3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	COGroup *document2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	/*COCollection *tag1 = [ctx insertObjectWithEntityName: @"Anonymous.Tag"];
	COCollection *tag2 = [ctx insertObjectWithEntityName: @"Anonymous.Tag"];
	
	COObject *person1 = [ctx insertObjectWithEntityName: @"Anonymous.Person"];
	COObject *person2 = [ctx insertObjectWithEntityName: @"Anonymous.Person"];
	COObject *person3 = [ctx insertObjectWithEntityName: @"Anonymous.Person"];	*/
	
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
	// Now make some changes
		
	[document2 setValue: @"My Shopping List" forProperty: @"label"]; [ctx commit];
	[document1 setValue: @"My Contacts" forProperty: @"label"]; [ctx commit];
	[leaf2 setValue: @"Tomatoes" forProperty: @"label"]; [ctx commit];
	[group2 addObject: leaf2]; [ctx commit];
	[document2 addObject: group2]; [ctx commit];
	[group2	setValue: @"Groceries" forProperty: @"label"]; [ctx commit];
	[group1 setValue: @"Work" forProperty: @"label"]; [ctx commit];
	[leaf3 setValue: @"Wine" forProperty: @"label"]; [ctx commit];
	[leaf1 setValue: @"Alice" forProperty: @"label"]; [ctx commit];
	
	NSLog(@"%@", [workspace debugDescription]);
	
	// FIXME: 
	UKPass();
	TearDownContext(ctx);
}
@end
