/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import <UnitKit/UnitKit.h>
#import "COObject.h"
#import "COGroup.h"
#import "COObjectContext.h"
#import "COObjectServer.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COUtility.h"

#define FM [NSFileManager defaultManager]
#define TMP_URL [NSURL fileURLWithPath: [FM tempDirectory]]
#define NEW(X) (AUTORELEASE([[X alloc] init]))

/* To eliminate a class name collision with other test suites */
#define SubObject SubRecordedObject
//#define SubGroup SubRecordedGroup

@interface SubObject : COObject
@end

@interface COObjectServer (Test)
+ (void) makeNewDefaultServer;
@end

@interface COObjectContext (Private)
- (int) latestVersion;
@end

@interface COObjectContext (TestObjectContext) <UKTest>
@end

@implementation COObjectContext (TestObjectContext)

- (id) objectByRestoringObject: (id)object toVersion: (int)aVersion 
{
	return [self objectByRestoringObject: object toVersion: aVersion mergeImmediately: NO];
}

- (id) initForTest
{
	/* Empty the cache in case other test classes don't do it in -releaseForTest.
	   If the cache doesn't get emptied, cached objects may point to invalid 
	   contexts each time a context is released. COObject->_objectContext is a 
	   weak refence.
	   TODO: Implement a cleanup strategy for contexts that got released. */
	[COObjectServer makeNewDefaultServer];
	[COGroup setAutomaticallyMakeNewInstancesPersistent: YES];
	[COObjectContext setCurrentContext: self];
	return [self init];
}

- (void) releaseForTest
{
	[COObjectServer makeNewDefaultServer];
	[COGroup setAutomaticallyMakeNewInstancesPersistent: NO];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];
	[super release];
}

- (void) testInit
{
	UKNotNil([[self class] currentContext]);
}

- (void) testLatestVersion
{
	/* Test New Context */
	id ctxt = [[[self class] alloc] init];
	id ctxtUUID = [ctxt UUID];
	UKIntsEqual(0, [ctxt latestVersion]);
	
	[[self class] setCurrentContext: ctxt];
	
	COObject *object = NEW(SubObject);
	[object setValue: @"me" forProperty: @"whoami"];	
	UKIntsEqual(2, [ctxt latestVersion]);
	
	RETAIN(ctxtUUID);
	DESTROY(ctxt);
	
	/* Test Recreate Context */
	ctxt = [(COObjectContext *)[[self class] alloc] initWithUUID: ctxtUUID];
	RELEASE(ctxtUUID);	
	UKIntsEqual(2, [ctxt latestVersion]);
	
	object = NEW(SubObject);
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(4, [ctxt latestVersion]);
	
	[[self class] setCurrentContext: NEW(COObjectContext)];
	DESTROY(ctxt);
}

- (void) testResolvedObjectForFault
{
	COObject *object = NEW(SubObject);
	
	[object setValue: @"me" forProperty: @"whoami"];
	
	UKObjectsSame(object, [self resolvedObjectForFault: [object UUID]]);
	
	[self unregisterObject: object];
	
	id newObject = [self resolvedObjectForFault: [object UUID]];
	
	UKObjectsNotSame(object, newObject);
	UKObjectsEqual(object, newObject); // version and UUID are identical
	UKTrue([[self registeredObjects] containsObject: newObject]);
}

- (void) testObjectForUUID
{
	COObject *object = NEW(SubObject);
	
	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	
	UKObjectsSame(object, [self objectForUUID: [object UUID]]);
	
	[self unregisterObject: object];
	
	id newObject = [self objectForUUID: [object UUID]];
	
	UKObjectsNotSame(object, newObject);
	UKObjectsEqual(object, newObject); // version and UUID are identical
	UKTrue([[self registeredObjects] containsObject: newObject]);
}

- (void) testLastVersionOfObject
{
	COObject *object = NEW(SubObject);

	COObjectContext *ctxt = [object objectContext];
	NSArray *manyNames = A(@"A", @"B", @"C", @"D", @"E", @"F", @"I", @"G", @"H");

	//ETLog(@"UUID is %@ for %@ at URL %@ ", [object UUID], object, [ctxt serializationURLForObject: object]);
	UKIntsEqual(0, [ctxt lastVersionOfObject: object]);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(1, [ctxt lastVersionOfObject: object]);
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	UKIntsEqual(2, [ctxt lastVersionOfObject: object]);
	/* We increment the version to a relatively high number, so we can be sure 
	   the test doesn't accidentally pass because we look in the wrong object 
	   bundle. Most of other object bundles created in tests have a version 
	   around 3 or 4. */
	FOREACHI(manyNames, name)
	{
		[object setValue: name forProperty: @"whoami"];
	}
	UKIntsEqual(2 + [manyNames count], [ctxt lastVersionOfObject: object]);
}

- (void) testBasicSnapshotRollback
{
	COObject *object = NEW(SubObject);

	UKObjectsEqual([[self class] currentContext], [object objectContext]);
	UKIntsEqual(0, [object objectVersion]);

	/* This first recorded invocation results in a snapshot with version 0, 
       immediately followed by an invocation record with version 1. */
	[object setValue: @"me" forProperty: @"whoami"];
	UKIntsEqual(1, [object objectVersion]);
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];
	UKIntsEqual(3, [object objectVersion]);

	id object1v3 = [[object objectContext] objectByRestoringObject: object toVersion: 0];
	UKStringsEqual(@"Nobody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSMutableArray arrayWithObject: @"New York"], [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testPlaybackBasedRollback
{
	COObject *object = NEW(SubObject);

	UKObjectsEqual(self, [object objectContext]);

	[object setValue: @"me" forProperty: @"whoami"];
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];

	UKIntsEqual(3, [object objectVersion]);

	id object1v1 = [self objectByRestoringObject: object toVersion: 1];
	UKNil([object1v1 objectContext]);
	UKObjectsEqual([object UUID], [object1v1 UUID]);
	UKStringsEqual(@"me", [object1v1 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray arrayWithObject: @"New York"], [object1v1 valueForProperty: @"otherObjects"]);

	id object1v2 = [self objectByRestoringObject: object toVersion: 2];
	UKObjectsEqual([object UUID], [object1v2 UUID]);
	UKStringsEqual(@"me", [object1v2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v2 valueForProperty: @"otherObjects"]);

	id object1v3 = [self objectByRestoringObject: object toVersion: 3];
	UKObjectsEqual([object UUID], [object1v3 UUID]);
	UKStringsEqual(@"everybody", [object1v3 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [object1v3 valueForProperty: @"otherObjects"]);
}

- (void) testMultiObjectPersistency
{
	COObject *object = NEW(SubObject);
	COObject *object2 = NEW(SubObject);

	[object setValue: @"me" forProperty: @"whoami"]; // version 1
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];
	[object setValue: @"everybody" forProperty: @"whoami"];
	[object setValue: @"you" forProperty: @"whoami"];
	[object setValue: [NSArray array] forProperty: @"otherObjects"];
	[object setValue: @"... hm not sure" forProperty: @"whoami"];
	[object2 setValue: @"fox" forProperty: @"whoami"]; // version 1
	UKIntsEqual(1, [object2 objectVersion]);
	[object setValue: @"Who knows!" forProperty: @"whoami"]; // version 7
	[object2 setValue: @"wolf" forProperty: @"whoami"];
	[object2 setValue: @"rabbit" forProperty: @"whoami"];
	[object setValue: @"My name is no name!" forProperty: @"whoami"];

	UKIntsEqual(8, [object objectVersion]);
	UKIntsEqual(3, [object2 objectVersion]);

	id object1v7 = [self objectByRestoringObject: object toVersion: 7];
	UKNil([object1v7 objectContext]);
	UKObjectsEqual([object UUID], [object1v7 UUID]);
	UKStringsEqual(@"Who knows!", [object1v7 valueForProperty: @"whoami"]);
	UKObjectsEqual([NSArray array], [object1v7 valueForProperty: @"otherObjects"]);
}

#define DOC(comment)
#define CREATE_OBJECT_GRAPH\
	COObject *object = NEW(SubObject);\
	COObject *object2 = NEW(SubObject);\
	COObject *object3 = NEW(SubObject);\
	COGroup *group = NEW(COGroup);\
	COGroup *group2 = NEW(COGroup);\
	COGroup *group3 = NEW(COGroup);\
\
	UKObjectsEqual(self, [object objectContext]);\
	UKObjectsEqual(self, [group objectContext]);\
\
	[group2 setValue: @"blizzard" forProperty: kCOGroupNameProperty];\
	[group2 setValue: @"cloud" forProperty: kCOGroupNameProperty];\
	[group2 addMember: object2]; DOC(version 3)\
	[group2 setValue: @"tulip" forProperty: kCOGroupNameProperty];\
	[group addMember: object];\
	[group addGroup: group2]; DOC(version 2)\
	[group addGroup: group3]; DOC(version 3)\
	[group removeGroup: group2]; DOC(version 4)\
	[group2 addMember: object3];\
\
	[object setValue: @"me" forProperty: @"whoami"]; DOC(version 1)\
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];\

- (void) testMerge
{
	COObject *object = NEW(SubObject);
	COObject *object2 = NEW(SubObject);
	COObject *object3 = NEW(SubObject);
	COGroup *group = NEW(COGroup);
	COGroup *group2 = NEW(COGroup);

	UKObjectsEqual(self, [object objectContext]);
	UKObjectsEqual(self, [group objectContext]);

	[group2 setValue: @"blizzard" forProperty: kCOGroupNameProperty];
	[group2 setValue: @"cloud" forProperty: kCOGroupNameProperty];
	[group2 addMember: object2]; // version 3
	[group2 setValue: @"tulip" forProperty: kCOGroupNameProperty];
	[group addMember: object];
	[group addGroup: group2];
	[group2 addMember: object3];

	[object setValue: @"me" forProperty: @"whoami"]; // version 1
	[object setValue: A(@"New York", @"Minneapolis", @"London") forProperty: @"otherObjects"];

	/* Test Object Merge */

	int objectVersionBeforeMerge = [object objectVersion];
	int groupVersionBeforeMerge = [group objectVersion];
	id objectv1 = [self objectByRestoringObject: object toVersion: 1 mergeImmediately: YES];

	/* Test merged object */
	UKNotNil([objectv1 objectContext]);
	UKStringsEqual(@"me", [objectv1 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [objectv1 valueForProperty: @"otherObjects"]);
	UKIntsEqual(objectVersionBeforeMerge + 1, [objectv1 objectVersion]); // version is incremented when the merge is committed

	/* Test replaced object */
	UKNil([object objectContext]);
	UKIntsEqual(objectVersionBeforeMerge, [object objectVersion]);

	/* Test parent to child references*/
	UKFalse([[group members] containsObject: object]);
	UKTrue([[group members] containsObject: objectv1]);
	UKFalse([group containsTemporalInstance: objectv1]); // objectv1 shouldn't be a temporal instance once it's inserted
	UKObjectsSame([[group members] objectAtIndex: 0], objectv1);

	/* Test child to parent referencess */
	UKTrue([[object valueForProperty: kCOParentsProperty] isEmpty]);
	UKIntsEqual(1, [[objectv1 valueForProperty: kCOParentsProperty] count]);
	UKTrue([[objectv1 valueForProperty: kCOParentsProperty] containsObject: group]);
	UKIntsEqual(0, [[objectv1 valueForProperty: kCOParentsProperty] indexOfObjectIdenticalTo: group]);

	/* Test parent group */
	UKIntsEqual(groupVersionBeforeMerge, [group objectVersion]); // just a temporal replacement, no serialization should occur

	/* Test context state */
	UKFalse([[self registeredObjects] containsObject: object]);
	UKTrue([[self registeredObjects] containsObject: objectv1]);

	/* Test Group Merge */

	groupVersionBeforeMerge = [group objectVersion];
	int group2VersionBeforeMerge = [group2 objectVersion];
	id group2v3 = [self objectByRestoringObject: group2 toVersion: 3 mergeImmediately: YES];

	/* Test merged object */
	UKNotNil([group2v3 objectContext]);
	UKStringsEqual(@"cloud", [group2v3 valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(object2), [group2v3 members]);
	UKIntsEqual(group2VersionBeforeMerge + 1, [group2v3 objectVersion]); // version is incremented when the merge is committed

	/* Test replaced object */
	UKNil([group2 objectContext]);
	UKIntsEqual(group2VersionBeforeMerge, [group2 objectVersion]);

	/* Test parent to child references*/
	UKFalse([[group members] containsObject: group2]);
	UKTrue([[group members] containsObject: group2v3]); // parent to child relationship is versionned by the parent in all cases
	UKFalse([group containsTemporalInstance: group2v3]); // group2v3 shouldn't be a temporal instance once it's inserted
	UKObjectsSame([[group groups] objectAtIndex: 0], group2v3);

	/* Test child to parent referencess */
	UKTrue([[group2 valueForProperty: kCOParentsProperty] isEmpty]);
	UKIntsEqual(1, [[group2v3 valueForProperty: kCOParentsProperty] count]);
	UKTrue([[group2v3 valueForProperty: kCOParentsProperty] containsObject: group]);
	UKIntsEqual(0, [[group2v3 valueForProperty: kCOParentsProperty] indexOfObjectIdenticalTo: group]);

	/* Test parent group */
	UKIntsEqual(groupVersionBeforeMerge, [group objectVersion]); // just a temporal replacement, no serialization should occur
}

- (void) testOldChildrenMergePolicy
{
	CREATE_OBJECT_GRAPH

	/* Test Old Children Merge */
	[self setMergePolicy: COOldChildrenMergePolicy];
	id groupv2 = [self objectByRestoringObject: group toVersion: 2 mergeImmediately: YES];

	UKObjectsEqual(A(object, group2), [groupv2 members]);
}

- (void) testExistingChildrenMergePolicy
{
	CREATE_OBJECT_GRAPH

	[self setMergePolicy: COExistingChildrenMergePolicy];
	id groupv2 = [self objectByRestoringObject: group toVersion: 2 mergeImmediately: YES];

	UKObjectsEqual(A(object, group3), [groupv2 members]);
}

- (void) testChildrenUnionMergePolicy
{
	CREATE_OBJECT_GRAPH

	[self setMergePolicy: COChildrenUnionMergePolicy];
	id groupv2 = [self objectByRestoringObject: group toVersion: 2 mergeImmediately: YES];

	/* Merging isn't expected to respect the children */
	id childrenUnionv2v4 = [NSSet setWithObjects: object, group2, group3, nil];
	UKObjectsEqual(childrenUnionv2v4, [NSSet setWithArray: [groupv2 members]]);
}

- (void) testChildrenIntersectionMergePolicy
{
	CREATE_OBJECT_GRAPH

	[self setMergePolicy: COChildrenIntersectionMergePolicy];
	id groupv2 = [self objectByRestoringObject: group toVersion: 2 mergeImmediately: YES];

	/* Merging isn't expected to respect the children, use NSSet if more than one child */
	UKObjectsEqual(A(object), [groupv2 members]);
}

- (void) testOneStepContextRollback
{
	UKIntsEqual(0, [self version]);

	CREATE_OBJECT_GRAPH
	id objectServer = [self objectServer];
	int lastVersion = 17;

	UKIntsEqual(lastVersion, [self version]);

	/* Move back to the previous version (undo) */

	[self restoreToVersion: lastVersion - 1];
	UKIntsEqual((lastVersion + 1), [self version]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [objectServer cachedObjectForUUID: [object UUID]];

	UKObjectsEqual([object UUID], [newObject UUID]);
	UKObjectsNotEqual(object, newObject);
	UKTrue([newObject isTemporalInstance: object]);
	UKIntsEqual([object objectVersion] + 1, [newObject objectVersion]);
	UKStringsEqual([object valueForProperty: @"whoami"], [newObject valueForProperty: @"whoami"]);
	UKStringsEqual(@"me", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	/* Move back to the initial version (redo) */
	[self restoreToVersion: lastVersion];
	UKIntsEqual((lastVersion + 2), [self version]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject2 = [objectServer cachedObjectForUUID: [newObject UUID]];

	UKObjectsEqual([object UUID], [newObject2 UUID]);
	UKObjectsNotEqual(object, newObject2);
	UKTrue([newObject2 isTemporalInstance: object]);
	UKTrue([newObject2 isTemporalInstance: newObject]);
	UKIntsEqual([object objectVersion] + 2, [newObject2 objectVersion]);
	UKStringsEqual([object valueForProperty: @"whoami"], [newObject2 valueForProperty: @"whoami"]);
	UKStringsEqual(@"me", [newObject2 valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York", @"Minneapolis", @"London"), [newObject2 valueForProperty: @"otherObjects"]);
}

- (void) testMultiStepContextRollback
{
	UKIntsEqual(0, [self version]);

	CREATE_OBJECT_GRAPH
	id objectServer = [self objectServer];
	int lastVersion = 17;

	UKIntsEqual(lastVersion, [self version]);

	/* Move back to the previous version (undo) */

	[self restoreToVersion: 12];
	UKIntsEqual((lastVersion + 1), [self version]);

	/* Merged instance has replaced the existing instance in the core object cache */
	id newObject = [objectServer cachedObjectForUUID: [object UUID]];

	UKObjectsEqual([object UUID], [newObject UUID]);
	UKObjectsNotEqual(object, newObject);
	UKTrue([newObject isTemporalInstance: object]);
	UKIntsEqual([object objectVersion] + 1, [newObject objectVersion]);
	UKStringsNotEqual([object valueForProperty: @"whoami"], [newObject valueForProperty: @"whoami"]);
	UKStringsEqual(@"Nobody", [newObject valueForProperty: @"whoami"]);
	UKObjectsEqual(A(@"New York"), [newObject valueForProperty: @"otherObjects"]);

	id newGroup = [objectServer cachedObjectForUUID: [group UUID]];
	id newGroup2 = [objectServer cachedObjectForUUID: [group2 UUID]];

	UKIntsEqual([group objectVersion] + 1, [newGroup objectVersion]);
	UKNil([newGroup valueForProperty: kCOGroupNameProperty]);
	UKObjectsEqual(A(newObject), [newGroup valueForProperty: kCOGroupChildrenProperty]);
	UKObjectsEqual(A(newGroup2), [newGroup valueForProperty: kCOGroupSubgroupsProperty]);

	UKIntsEqual([group2 objectVersion] + 1, [newGroup2 objectVersion]);
	UKStringsEqual(@"tulip", [newGroup2 valueForProperty: kCOGroupNameProperty]);
	/* object2 version doesn't change in CREATE_OBJECT_GRAPH, hence the initial instance is still valid */
	UKObjectsEqual(A(object2), [newGroup2 valueForProperty: kCOGroupChildrenProperty]);
	UKTrue([[newGroup2 valueForProperty: kCOGroupSubgroupsProperty] isEmpty]);
}

- (void) testGroupPersistency
{
	COObject *object = NEW(SubObject);
	COObject *object2 = NEW(SubObject);
	COObject *object3 = NEW(SubObject);
	COGroup *group = NEW(COGroup);
	COGroup *group2 = NEW(COGroup);

	UKObjectsEqual(self, [object3 objectContext]);
	UKObjectsEqual(self, [group objectContext]);
	UKIntsEqual(0, [object objectVersion]);
	UKIntsEqual(0, [group objectVersion]);
	UKIntsEqual(0, [group2 objectVersion]);

	[group2 addMember: object2];
	[group addMember: object];

	UKIntsEqual(0, [object objectVersion]);
	UKIntsEqual(1, [group objectVersion]);
	UKIntsEqual(1, [group2 objectVersion]);

	[group addGroup: group2];

	UKIntsEqual(2, [group objectVersion]);
	UKIntsEqual(1, [group2 objectVersion]);

	[group2 addMember: object3];

	UKIntsEqual(2, [group2 objectVersion]);

	/* Test snapshot rollback */
	id group1v0 = [self objectByRestoringObject: group toVersion: 0];
	UKNil([group1v0 objectContext]);
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKIntsEqual(2, [group objectVersion]);
	UKIntsEqual(2, [self lastVersionOfObject: group1v0]);
	//UKIntsEqual(2, [group1v0 lastObjectVersion]);
	UKTrue([group1v0 isEmpty]);
	UKFalse([group isEmpty]);
	UKObjectsEqual([group UUID], [group1v0 UUID]);
	/* Don't pass because we test equality only on type, UUID and object version. */
	UKObjectsNotEqual(group, group1v0);
	UKTrue([group1v0 isTemporalInstance: group]); 

	/* Test playback rollback (move forward in time) */
	id group1v2 = [self objectByRestoringObject: group1v0 toVersion: 2];
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKIntsEqual(0, [group1v0 objectVersion]);
	UKIntsEqual(2, [self lastVersionOfObject: group1v2]);
	UKFalse([group1v2 isEmpty]);
	UKObjectsNotEqual(group1v0, group1v2);
	UKObjectsEqual(group, group1v2); // We have return to 'group' state (most recent version)
	UKObjectsEqual([group1v0 UUID], [group1v2 UUID]);
	UKObjectsEqual([group UUID], [group1v2 UUID]);
	UKTrue([group1v2 isTemporalInstance: group1v0]); 
	// Two objects with the same UUID and version don't qualify as temporal instances
	UKFalse([group1v2 isTemporalInstance: group]);
	// FIXME: 
	//UKObjectsEqual([group members], [group1v2 members]);

	/* Test playback rollback (move backward in time) */
	id group1v1 = [self objectByRestoringObject: group1v2 toVersion: 1];
	UKIntsEqual(1, [group1v1 objectVersion]);
	UKIntsEqual(2, [group1v2 objectVersion]);
	UKFalse([group1v1 isEmpty]);
	UKObjectsNotEqual(group1v2, group1v1);
	UKObjectsEqual([group UUID], [group1v1 UUID]);
	UKTrue([group1v1 isTemporalInstance: group1v2]); 
	UKTrue([group1v1 isTemporalInstance: group1v0]);
	UKTrue([group1v1 isTemporalInstance: group]);
	// NOTE: The next two tests only holds if -objects doesn't return subgroups
	// UKObjectsEqual([group members], [group1v1 members]);
	UKObjectsNotEqual([group groups], [group1v1 groups]);
	// FIXME:
	//UKObjectsEqual(object, [[group1v1 members] objectAtIndex: 0]);
	//UKObjectsSame(object, [[group1v1 members] objectAtIndex: 0]);
}

- (void) testDummySerialization
{
#if 0
	id baseURL = [ETSerializer defaultLibraryURL];
	id inv = [NSInvocation invocationWithTarget: object selector: @selector(description) arguments: [NSArray array]];
	id serializer = [[ETSerializer serializerWithBackend: [ETSerializerBackendBinary class]
								 			  forURL: baseURL] retain];
	//[serializer serializeObject:object withName:@"TestBaseVersion"];
	//[inv setTarget: nil];
	int version = [serializer newVersion];
	[inv setTarget:nil];
	[serializer serializeObject: inv withName:@"TestDelta"];
	[serializer serializeObject: inv withName:@"Anything"];
#endif
}

@end

@implementation SubObject

+ (void) initialize
{
	[super initialize];

	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kCOStringProperty],
            @"whoami",
        [NSNumber numberWithInt: kCOArrayProperty],
            @"otherObjects",
        nil];
    [self addPropertiesAndTypes: pt];
	[self setAutomaticallyMakeNewInstancesPersistent: YES];

    DESTROY(pt);
}

- (id) init
{
	SUPERINIT

	[self setValue: @"Nobody"
	      forProperty: @"whoami"];
	[self setValue: [NSMutableArray arrayWithObject: @"New York"]
	      forProperty: @"otherObjects"];
	[self tryStartPersistencyIfInstanceOfClass: [SubObject class]];

	return self;
}

@end
