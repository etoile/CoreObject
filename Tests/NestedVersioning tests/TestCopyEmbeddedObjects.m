#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COContainer.h"
#import "COCollection.h"
#import "COObjectGraphDiff.h"
#import "TestCommon.h"

@interface TestCopy : NSObject <UKTest>
{
}
@end

@implementation TestCopy

#if 0

void test()
{
	/*
	 the interesting sort of corner case to test is:
	 */
	
	
	 // outline doc 1 <<persistent root>>
	 //  |
	 //  \--item 1
	 //      |
	 //      \-item 1a
	 //
	 // outline doc 2 <<persistent root>>
	
	 
	 /* Step 1: copy item 1 to outline doc 2 and make edits */
	
	
	// outline doc 1 <<persistent root>>
	//  |
	//  \--item 1
	//      |
	//      \-item 1a
	//
	// outline doc 2 <<persistent root>>
	//  |
	//  \--item 1 (with edit X)
	//      |
	//      \-item 1a (with edit Y)
	

	/* Step 2: move and edit doc1.item1a within doc 1 */
	
	
	// outline doc 1 <<persistent root>>
	//  |
	//  |--item 1
	//  |
	//  \-item 1a (with edit W)
	//
	// outline doc 2 <<persistent root>>
	//  |
	//  \--item 1 (with edit X)
	//      |
	//      \-item 1a (with edit Y)
	
	
	/* Step 3: copy doc2.item1 to doc1.
	 
		It's not clear what exactly should happen.
	 
	   Note that uuid(doc1.item1) == uuid(doc2.item1) and
	             uuid(doc1.item1a) == uuid(doc2.item1a).
		
		We should get the following tree. The only question is which item1a should be re-assigned a UUID.
	    The one in the tree being copied from doc2, or the one in doc1 that was edited in step 2.
	 
	 */
	
	
	// outline doc 1 <<persistent root>>
	//  |
	//  |--item 1 (with edit X)
	//  |   |
	//  |   \-item 1a (with edit Y)
	//  |
	//  \-item 1a (with edit W)
	//
	// outline doc 2 <<persistent root>>
	//  |
	//  \--item 1 (with edit X)
	//      |
	//      \-item 1a (with edit Y)
	
	
	/* method to test is:
	- (COUUID *) copyEmbeddedObject: (COUUID *)src
fromContext: (id<COEditingContext>)srcCtx;
insertInto: (COUUID *)dest
inContext: (id<COEditingContext>)destCtx
	*/
}

#endif



- (void)testBasic
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	
	COCollection *tag = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild1 setValue: @"Pizza" forProperty: @"label"];
	[subchild2 setValue: @"Salad" forProperty: @"label"];
	[subchild3 setValue: @"Chips" forProperty: @"label"];
	[child addObject: subchild1];
	[child addObject: subchild2];
	[child addObject: subchild3];
	[parent addObject: child];
	
	[tag addObject: parent];
	
	COContainer *parentCopy = [ctx1 insertObjectCopy: parent];
	UKObjectsEqual(S(tag), [parentCopy valueForProperty: @"parentCollections"]);
	UKObjectsEqual(@"Shopping", [parentCopy valueForProperty: @"label"]);
	UKObjectsEqual(S(parent, parentCopy), [tag content]);
	UKObjectsNotEqual([parent UUID], [parentCopy UUID]);
	
	UKIntsEqual(1, [[parentCopy contentArray] count]);
	if (1 == [[parentCopy contentArray] count])
	{
		COContainer *childCopy = [[parentCopy contentArray] firstObject];
		UKObjectsEqual(@"Groceries", [childCopy valueForProperty: @"label"]);
		UKObjectsSame(parentCopy, [childCopy valueForProperty: @"parentContainer"]);
		UKObjectsNotEqual([child UUID], [childCopy UUID]);
		UKIntsEqual(3, [[childCopy contentArray] count]);
		if (3 == [[childCopy contentArray] count])
		{
			COContainer *subchild1Copy = [[childCopy contentArray] objectAtIndex: 0];
			UKObjectsEqual(@"Pizza", [subchild1Copy valueForProperty: @"label"]);
			UKObjectsSame(childCopy, [subchild1Copy valueForProperty: @"parentContainer"]);
			UKObjectsNotEqual([subchild1 UUID], [subchild1Copy UUID]);

			COContainer *subchild2Copy = [[childCopy contentArray] objectAtIndex: 1];
			UKObjectsEqual(@"Salad", [subchild2Copy valueForProperty: @"label"]);
			UKObjectsSame(childCopy, [subchild2Copy valueForProperty: @"parentContainer"]);
			UKObjectsNotEqual([subchild2 UUID], [subchild2Copy UUID]);

			COContainer *subchild3Copy = [[childCopy contentArray] objectAtIndex: 2];
			UKObjectsEqual(@"Chips", [subchild3Copy valueForProperty: @"label"]);
			UKObjectsSame(childCopy, [subchild3Copy valueForProperty: @"parentContainer"]);
			UKObjectsNotEqual([subchild3 UUID], [subchild3Copy UUID]);
		}
	}

	
	[ctx1 release];
}

@end
