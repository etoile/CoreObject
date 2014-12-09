/*
	Copyright (C) 2014 Quentin Mathé

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestSchemaMigration : EditingContextTestCase <UKTest>
{
	COEditingContext *migrationCtx;
	OutlineItem *parent;
	OutlineItem *child;
}

@end

@implementation TestSchemaMigration

- (id)init
{
	SUPERINIT;
	parent = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
	child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
	[parent addObject: child];
	return self;
}

- (void) prepareNewMigrationContextForDestinationVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];

	repo.anonymousPackageDescription.version = version;
	migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
	                            modelDescriptionRepository: repo];
}

- (void) testSchemaVersion
{
	[self checkPersistentRootWithExistingAndNewContext: [parent persistentRoot]
	                                           inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		OutlineItem *newParent = [testPersistentRoot rootObject];
		OutlineItem *newChild = [[newParent content] firstObject];
	
		UKIntsEqual(0, [newParent.objectGraphContext schemaVersion]);
		UKIntsEqual(0, [[newParent.storeItem valueForAttribute: kCOObjectSchemaVersionProperty] longLongValue]);
		UKIntsEqual(0, [[newChild.storeItem valueForAttribute: kCOObjectSchemaVersionProperty] longLongValue]);
	}];
}

#if 0
- (void) testBasicMigrationWithoutMetamodelChanges
{
	[ctx commit];
	[self prepareNewMigrationContextForDestinationVersion: 1];

	COObjectGraphContext *context = parent.objectGraphContext;
	COSchemaMigration *migration = [COSchemaMigration new];

	migration.domain = @"org.etoile-project.CoreObject";
	migration.destinationVersion = 1;
	migration.migrationBlock = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *item in [[storeItems mappedCollection] mutableCopy])
		{
			[item setValue: @"Untitled" forAttribute: @"name"];

			[migratedItems addObject: item];
		}
		return migratedItems;
	};
	[COSchemaMigration registerMigration: migration];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(1, migratedContext.schemaVersion);
	UKStringsEqual(@"Untitled", migratedParent.label);
	UKStringsEqual(@"Untitled", migratedChild.label);
	UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}
#endif

- (void) testInsertOrUpdateItemsWithoutMigration
{
	COObjectGraphContext *context = parent.objectGraphContext;
	
	UKDoesNotRaiseException([context insertOrUpdateItems: [context items]]);
}

/*	- (void) testInsertOrUpdateItemsWithMigration
 COObject *newParent =
 [migrationCtx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
 
	[newParent]*/

- (void)testExceptionOnFutureSchemaVersion
{
	COMutableItem *parentItem = [parent.storeItem mutableCopy];

	[parentItem setValue: @(1) forAttribute: kCOObjectSchemaVersionProperty];

	UKRaisesException([parent.objectGraphContext insertOrUpdateItems: A(parentItem)]);
}
					  
- (void)testExceptionOnNegativeSchemaVersion
{
	COMutableItem *parentItem = [parent.storeItem mutableCopy];

	[parentItem setValue: @(-1) forAttribute: kCOObjectSchemaVersionProperty];

	UKRaisesException([parent.objectGraphContext insertOrUpdateItems: A(parentItem)]);
}

- (void)textExceptionOnMissingMigration
{
	
}

/*- (void) testInsertOrUpdateItemsWithoutMigration
{
	OutlineItem *otherChild = [[ctx insertNewPersistentRootWithEntityName: @"OutlineItem"] rootObject];

	[self checkPersistentRootWithExistingAndNewContext: [parent persistentRoot]
	                                           inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		OutlineItem *newParent = [testPersistentRoot rootObject];

		UKDoesNotRaiseException([newParent.objectGraphContext insertOrUpdateItems: [newParent.objectGraphContext items]]);
	}];
}*/

@end
