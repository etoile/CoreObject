#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"
#import "COGroup.h"

@interface TestEditingContext : NSObject <UKTest>
{
}
@end

@implementation TestEditingContext

- (id) init
{
	self = [super init];
	return self;
}
- (void)testCreate
{
	COEditingContext *ctx = NewContext();
	UKNotNil(ctx);
	TearDownContext(ctx);
}

- (void)testInsertObject
{
	COEditingContext *ctx = NewContext();
	UKFalse([ctx hasChanges]);
	
	
	COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	UKNotNil(obj);
	UKTrue([obj isKindOfClass: [COObject class]]);
	
	NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentGroup", @"parentCollections", @"contents", @"label", nil];
	UKObjectsEqual([NSSet setWithArray: expectedProperties],
				   [NSSet setWithArray: [obj properties]]);

	UKObjectsSame(obj, [ctx objectWithUUID: [obj UUID]]);
	
	UKTrue([ctx hasChanges]);
	
	TearDownContext(ctx);
}

- (void)testBasicPersistence
{
	ETUUID *objUUID;
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
		objUUID = [[obj UUID] retain];
		[obj setValue: @"Hello" forProperty: @"label"];
		[ctx commit];
		[ctx release];
		[store release];
	}
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx objectWithUUID: objUUID];
		UKNotNil(obj);
		NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentGroup", @"parentCollections", @"contents", @"label", nil];
		UKObjectsEqual([NSSet setWithArray: expectedProperties],
					   [NSSet setWithArray: [obj properties]]);
		UKStringsEqual(@"Hello", [obj valueForProperty: @"label"]);
		[ctx release];
		[store release];
	}
	[objUUID release];
	DELETE_STORE;
}


- (void)testDiscardChanges
{
	COEditingContext *ctx = NewContext();

	UKFalse([ctx hasChanges]);
		
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	ETUUID *u1 = [[o1 UUID] retain];
	
	// FIXME: It's not entirely clear what this should do
	[ctx discardAllChanges];
	UKNil([ctx objectWithUUID: u1]);
	
	UKFalse([ctx hasChanges]);
	COObject *o2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o2 setValue: @"hello" forProperty: @"label"];
	[ctx commit];
	UKObjectsEqual(@"hello", [o2 valueForProperty: @"label"]);
	
	[o2 setValue: @"bye" forProperty: @"label"];
	[ctx discardAllChanges];
	UKObjectsEqual(@"hello", [o2 valueForProperty: @"label"]);
	
	TearDownContext(ctx);
}

- (void)testCopyingBetweenContextsWithNoStoreSimple
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];

	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o1 setValue: @"Shopping" forProperty: @"label"];
	
	COObject *o1copy = [ctx2 insertObject: o1 fromContext: ctx1];
	UKNotNil(o1copy);
	UKObjectsSame(ctx1, [o1 editingContext]);
	UKObjectsSame(ctx2, [o1copy editingContext]);
	UKStringsEqual(@"Shopping", [o1copy valueForProperty: @"label"]);

	[ctx1 release];
	[ctx2 release];
}

- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COGroup *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *subchild = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];

	// We are going to copy 'child' from ctx1 to ctx2. It should copy both
	// 'child' and 'subchild', but not 'parent'
	
	COGroup *childCopy = [ctx2 insertObject: child fromContext: ctx1];
	UKNotNil(childCopy);
	UKObjectsSame(ctx2, [childCopy editingContext]);
	UKNil([childCopy valueForProperty: @"parentGroup"]);
	UKStringsEqual(@"Groceries", [childCopy valueForProperty: @"label"]);
	UKNotNil([childCopy contentArray]);
	
	COGroup *subchildCopy = [[childCopy contentArray] firstObject];
	UKNotNil(subchildCopy);
	UKObjectsSame(ctx2, [subchildCopy editingContext]);
	UKStringsEqual(@"Pizza", [subchildCopy valueForProperty: @"label"]);
				   
	[ctx1 release];
	[ctx2 release];
}

- (void)testCopyingBetweenContextsWithSharedStore
{
	COEditingContext *ctx1 = NewContext();
	COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: [ctx1 store]];
	
	COGroup *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *subchild = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];
	
	[ctx1 commit];
	
	// We'll add another sub-child and leave it uncommitted.
	COGroup *subchild2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[subchild2 setValue: @"Salad" forProperty: @"label"];
	[child addObject: subchild2];
	
	// We are going to copy 'child' from ctx1 to ctx2. It should copy
	// 'child', 'subchild', and 'subchild2', but not 'parent'
	
	COGroup *childCopy = [ctx2 insertObject: child fromContext: ctx1];
	UKNotNil(childCopy);
	UKObjectsSame(ctx2, [childCopy editingContext]);
	UKNil([childCopy valueForProperty: @"parentGroup"]);
	UKStringsEqual(@"Groceries", [childCopy valueForProperty: @"label"]);
	UKNotNil([childCopy contentArray]);
	
	COGroup *subchildCopy = [[childCopy contentArray] firstObject];
	UKNotNil(subchildCopy);
	UKObjectsSame(ctx2, [subchildCopy editingContext]);
	UKStringsEqual(@"Pizza", [subchildCopy valueForProperty: @"label"]);
	
	COGroup *subchild2Copy = [[childCopy contentArray] objectAtIndex: 1];
	UKNotNil(subchild2Copy);
	UKObjectsSame(ctx2, [subchild2Copy editingContext]);
	UKStringsEqual(@"Salad", [subchild2Copy valueForProperty: @"label"]);
	
	
	[ctx2 release];
	TearDownContext(ctx1);
}


- (void)testCopyingBetweenContextsCornerCases
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o1 setValue: @"Shopping" forProperty: @"label"];
	
	COObject *o1copy = [ctx2 insertObject: o1 fromContext: ctx1];
	
	// Insert again
	COObject *o1copy2 = [ctx2 insertObject: o1 fromContext: ctx1];
	UKObjectsSame(o1copy, o1copy2);
	
	//FIXME: Should inserting again copy over new changes (if any)?
	
	[ctx1 release];
	[ctx2 release];
}

@end
