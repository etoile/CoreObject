#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COContainer.h"
#import "COGroup.h"
#import "TestCommon.h"

@interface TestCopy : TestCommon <UKTest>
@end

@implementation TestCopy

#if 0
- (void)testBasic
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	
	COGroup *tag = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
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
	UKObjectsEqual([NSSet set], [parentCopy valueForProperty: @"parentCollections"]);
	UKObjectsEqual(@"Shopping", [parentCopy valueForProperty: @"label"]);
	UKObjectsEqual(S(parent), [tag content]);
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
#endif

@end
