#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COContainer.h"
#import "COGroup.h"
#import "COStore.h"
#import "TestCommon.h"

@interface TestEditingContext : TestCommon <UKTest>
@end

/**
 * A class to test the -[COObject didCreate] method (unfortunately no anonymous 
 * classes in this language).
 */
@interface TestCreateExample : COObject
{
	NSInteger didCreateCalled;
}
- (NSInteger)didCreateCalled;
@end

@implementation TestCreateExample
- (NSInteger)didCreateCalled
{
	return didCreateCalled;
}
- (void)didCreate
{
	[super didCreate];
	didCreateCalled++;
}
@end

@implementation TestEditingContext

- (void)testCreate
{
	UKNotNil(ctx);
}

- (void)testContextWithNoStore
{
	COEditingContext *ctx2 = [[COEditingContext alloc] init];

	UKNil([ctx2 store]);
	/* In case, -latestRevisionNumber sent to a nil store doesn't behave correctly */
	UKIntsEqual(0, [ctx2 latestRevisionNumber]);

	DESTROY(ctx2);
}

- (NSSet *)basicProperties
{
	return S(@"name", @"parentContainer", @"parentCollections", @"contents", @"label", @"tags");
}

- (void)testInsertObject
{
	UKFalse([ctx hasChanges]);

	COObject *obj = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
		
	UKNotNil(obj);
	UKTrue([obj isKindOfClass: [COObject class]]);
	UKObjectsEqual([self basicProperties], SA([obj persistentPropertyNames]));
	UKNotNil([obj valueForProperty: @"parentCollections"]);
	UKNotNil([obj valueForProperty: @"contents"]);

	UKObjectsSame(ctx, [[obj editingContext] parentContext]);
	UKObjectsSame(obj, [[obj editingContext] objectWithUUID: [obj UUID]]);
	UKTrue([[ctx loadedObjects] containsObject: obj]);
	UKTrue([[ctx loadedRootObjects] containsObject: obj]);

	UKTrue([[[obj editingContext] insertedObjects] containsObject: obj]);
	UKTrue([[ctx insertedObjects] containsObject: obj]);
	UKTrue([[[obj editingContext] changedObjects] containsObject: obj]);
	UKTrue([[ctx changedObjects] containsObject: obj]);
	UKTrue([[obj editingContext] hasChanges]);
	UKTrue([ctx hasChanges]);
}

- (void)testUpdateObject
{
	UKFalse([ctx hasChanges]);
	
	COObject *obj = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];

	UKTrue([[[obj editingContext] updatedObjects] isEmpty]);
	UKTrue([[ctx updatedObjects] isEmpty]);

	[obj setValue: @"Hello" forProperty: @"label"];

	UKTrue([[[obj editingContext] updatedObjects] containsObject: obj]);
	UKTrue([[ctx insertedObjects] containsObject: obj]);
	UKTrue([[[obj editingContext] updatedObjects] containsObject: obj]);
	UKTrue([[ctx changedObjects] containsObject: obj]);
	UKTrue([[obj editingContext] hasChanges]);
	UKTrue([ctx hasChanges]);
}

- (void)testDeleteObject
{
	UKFalse([ctx hasChanges]);
	
	COObject *obj = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
	
	UKTrue([[[obj editingContext] deletedObjects] isEmpty]);
	UKTrue([[ctx deletedObjects] isEmpty]);
	
	[[obj editingContext] deleteObject: obj];
	
	UKTrue([[[obj editingContext] deletedObjects] containsObject: obj]);
	UKTrue([[ctx deletedObjects] containsObject: obj]);
	UKTrue([[ctx changedObjects] containsObject: obj]);
	UKTrue([[obj editingContext] hasChanges]);
	UKTrue([ctx hasChanges]);
}

- (void)testBasicPersistence
{
	return;
	COPersistentRoot *persistentRoot =
		[[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] retain];
	COObject *obj = [persistentRoot rootObject];

	[obj setValue: @"Hello" forProperty: @"label"];
	
	UKTrue([ctx hasChanges]);

	[ctx commit];

	UKFalse([ctx hasChanges]);
	UKIntsEqual(1, [ctx latestRevisionNumber]);
	
	/* Recreate editing context and store */
		
	[self instantiateNewContextAndStore];

	UKFalse([ctx hasChanges]);
	UKIntsEqual(1, [ctx latestRevisionNumber]);
	
	/* Recreate persistent root and root object */

	/*COPersistentRoot *newPersistentRoot =
		[ctx contextForPersistentRootUUID: [persistentRoot persistentRootUUID]];
	COObject *newObj = [newPersistentRoot rootObject];*/
	COObject *newObj = [ctx objectWithUUID: [obj UUID]];
	COPersistentRoot *newPersistentRoot = [newObj editingContext];

	UKNotNil(newObj);
	UKObjectsEqual([obj UUID], [newObj UUID]);
	UKObjectsNotSame(obj, newObj);
	UKObjectsEqual([persistentRoot persistentRootUUID], [newPersistentRoot persistentRootUUID]);
	UKObjectsEqual([persistentRoot commitTrack], [newPersistentRoot commitTrack]);
	UKObjectsEqual([persistentRoot revision], [newPersistentRoot revision]);

	UKObjectsEqual([self basicProperties], SA([newObj persistentPropertyNames]));
	UKStringsEqual(@"Hello", [newObj valueForProperty: @"label"]);

	UKObjectsSame(newObj, [newPersistentRoot objectWithUUID: [newObj UUID]]);
	UKObjectsEqual([ctx loadedObjects], S(newObj));

	[persistentRoot release];
}

- (void)testDidCreate
{
	/* Test the two COObject instantiation paths, 
	   -[COEditingContext insertObjectWithEntityName:rootObject:] and -[COObject init] */
	TestCreateExample *obj = (id)[ctx insertObjectWithEntityName: @"Anonymous.TestCreateExample"];
	TestCreateExample *obj2 = [TestCreateExample new];

	UKIntsEqual(1, [obj didCreateCalled]);
	UKIntsEqual(1, [obj2 didCreateCalled]);

	[obj2 becomePersistentInContext: [ctx makePersistentRootContext]];

	UKIntsEqual(1, [obj2 didCreateCalled]);

	ETUUID *objUUID = [[obj UUID] retain];

	[ctx commit];

	[obj2 release];
	[self instantiateNewContextAndStore];

	obj = (id)[ctx objectWithUUID: objUUID];
	
	UKNotNil(obj);
	UKIntsEqual(0, [obj didCreateCalled]);
	
	[objUUID release];
}

- (void)testDiscardChanges
{
	UKFalse([ctx hasChanges]);
		
	COObject *o1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	ETUUID *u1 = [[o1 UUID] retain];

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
}

// TODO: Rework copying accross editing contexts (not yet possible to copy a persistent root)

- (void)testCopyingBetweenContextsWithNoStoreSimple
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];

	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o1 setValue: @"Shopping" forProperty: @"label"];
	COObject *o1copy = [ctx2 insertObject: o1];

	UKNotNil(o1copy);
	UKObjectsSame(ctx1, [(id)[o1 editingContext] parentContext]);
	UKObjectsSame(ctx2, [(id)[o1copy editingContext] parentContext]);
	UKStringsEqual(@"Shopping", [o1copy valueForProperty: @"label"]);

	[ctx1 release];
	[ctx2 release];
}

- (void)testCopyingBetweenContextsWithNoStoreAdvanced
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];

	// We are going to copy 'child' from ctx1 to ctx2. It should copy both
	// 'child' and 'subchild', but not 'parent'
	
	COContainer *childCopy = [ctx2 insertObject: child];
	UKNotNil(childCopy);
	UKObjectsSame(ctx2, [(id)[childCopy editingContext] parentContext]);
	UKNil([childCopy valueForProperty: @"parentContainer"]);
	UKStringsEqual(@"Groceries", [childCopy valueForProperty: @"label"]);
	UKNotNil([childCopy contentArray]);
	
	COContainer *subchildCopy = [[childCopy contentArray] firstObject];
	UKNotNil(subchildCopy);
	UKObjectsSame(ctx2, [(id)[subchildCopy editingContext] parentContext]);
	UKStringsEqual(@"Pizza", [subchildCopy valueForProperty: @"label"]);
				   
	[ctx1 release];
	[ctx2 release];
}

- (void)testCopyingBetweenContextsWithSharedStore
{
	COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: [ctx store]];
	
	COContainer *parent = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];
	
	[ctx commit];
	
	// We won't commit this
	[parent setValue: @"Todo" forProperty: @"label"];
	
	// We'll add another sub-child and leave it uncommitted.
	COContainer *subchild2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[subchild2 setValue: @"Salad" forProperty: @"label"];
	[child addObject: subchild2];
	
	// We are going to copy 'child' from ctx to ctx2. It should copy
	// 'child', 'subchild', and 'subchild2', but not 'parent' (so 
	// renaming parent from "Shopping" to "Todo" should not be propagated.)
	COContainer *childCopy = [ctx2 insertObject: child];

	UKNotNil(childCopy);
	UKObjectsSame(ctx2, [(id)[childCopy editingContext] parentContext]);
	UKObjectsEqual([parent UUID], [[childCopy valueForProperty: @"parentContainer"] UUID]);
	UKStringsEqual(@"Shopping", [[childCopy valueForProperty: @"parentContainer"] valueForProperty: @"label"]);
	UKStringsEqual(@"Groceries", [childCopy valueForProperty: @"label"]);
	UKNotNil([childCopy contentArray]);
	UKIntsEqual(2, [[childCopy contentArray] count]);

	if (2 == [[childCopy contentArray] count])
	{
		COContainer *subchildCopy = [[childCopy contentArray] firstObject];
		UKNotNil(subchildCopy);
		UKObjectsSame(ctx2, [(id)[subchildCopy editingContext] parentContext]);
		UKStringsEqual(@"Pizza", [subchildCopy valueForProperty: @"label"]);
		
		COContainer *subchild2Copy = [[childCopy contentArray] objectAtIndex: 1];
		UKNotNil(subchild2Copy);
		UKObjectsSame(ctx2, [(id)[subchild2Copy editingContext] parentContext]);
		UKStringsEqual(@"Salad", [subchild2Copy valueForProperty: @"label"]);
	}

	[ctx2 release];
}


- (void)testCopyingBetweenContextsCornerCases
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];

	COObject *o1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[o1 setValue: @"Shopping" forProperty: @"label"];
	COObject *o1copy = [ctx2 insertObject: o1];
	// Insert again
	COObject *o1copy2 = [ctx2 insertObject: o1];

	UKObjectsSame(o1copy, o1copy2);
	
	//FIXME: Should inserting again copy over new changes (if any)?
	
	[ctx1 release];
	[ctx2 release];
}

- (void)testCopyingBetweenContextsWithManyToMany
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];

	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

	[tag1 addObject: child];

	// Copy the tag collection to ctx2. At first it will be empty since child isn't in ctx2 yet
	
	COGroup *tag1copy = [ctx2 insertObject: tag1];
	UKObjectsEqual([NSArray array], [tag1copy contentArray]);
	
	COContainer *childcopy = [ctx2 insertObject: child];
	UKObjectsEqual(A(childcopy), [tag1copy contentArray]);
	
	[ctx1 release];
	[ctx2 release];
}

@end
