/*
	Copyright (C) 2014 Quentin Mathé

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface COSchemaMigration ()
+ (void)clearRegisteredMigrations;
@end

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
	[COSchemaMigration clearRegisteredMigrations];
	SUPERINIT;
	parent = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
	child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
	[parent addObject: child];
	return self;
}

- (void)dealloc
{
	[COSchemaMigration clearRegisteredMigrations];
}

- (void)prepareNewMigrationContextForDestinationVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
	CORegisterCoreObjectMetamodel(repo);

	ETPackageDescription *testPackage = [repo descriptionForName: @"Test"];
	ETAssert(testPackage != nil);
	ETPackageDescription *coreObjectPackage =
		[repo descriptionForName: @"org.etoile-project.CoreObject"];
	ETAssert(coreObjectPackage != nil);

	testPackage.version = 1;
	ETAssert(coreObjectPackage.version == 0);

	migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
	                            modelDescriptionRepository: repo];
}

- (void)testItemVersionsFromSerialization
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: parent.objectGraphContext
	                                                   inBlock: ^(COObjectGraphContext *testGraph, id testRootObject, BOOL isObjectGraphCopy)
	{
		OutlineItem *newParent = testRootObject;
		OutlineItem *newChild = [[newParent content] firstObject];
	
		UKObjectsEqual(A(@(0), @(0)), [newParent.storeItem valueForAttribute: kCOObjectVersionsProperty]);
		UKObjectsEqual(A(@(0), @(0)), [newChild.storeItem valueForAttribute: kCOObjectVersionsProperty]);

		UKObjectsEqual(A(@"Test", @"org.etoile-project.CoreObject"), [newParent.storeItem valueForAttribute: kCOObjectDomainsProperty]);
		UKObjectsEqual(A(@"Test", @"org.etoile-project.CoreObject"), [newChild.storeItem valueForAttribute: kCOObjectDomainsProperty]);
	}];
}

- (COSchemaMigration *)registerMigrationWithVersion: (int64_t)version domain: (NSString *)domain
{
	COSchemaMigration *migration = [COSchemaMigration new];
	
	migration.domain = domain;
	migration.destinationVersion = version;
	
	[COSchemaMigration registerMigration: migration];
	return migration;
}

- (void)testSchemaMigrationRegistration
{
	COSchemaMigration *migration1 = [self registerMigrationWithVersion: 500 domain: @"Test"];
	COSchemaMigration *migration2 = [self registerMigrationWithVersion: 501 domain: @"Test"];
	COSchemaMigration *migration3 =
		[self registerMigrationWithVersion: 500 domain: @"org.etoile-project.CoreObject"];

	UKObjectsEqual(migration1, [COSchemaMigration migrationForDomain: @"Test" destinationVersion: 500]);
	UKObjectsEqual(migration2, [COSchemaMigration migrationForDomain: @"Test" destinationVersion: 501]);
	UKObjectsEqual(migration3, [COSchemaMigration migrationForDomain: @"org.etoile-project.CoreObject"
	                                              destinationVersion: 500]);
	UKNil([COSchemaMigration migrationForDomain: @"org.etoile-project.CoreObject"
							 destinationVersion: 501]);
}

- (void)testBasicMigrationWithoutMetamodelChanges
{
	COSchemaMigration *migration = [COSchemaMigration new];

	migration.domain = @"Test";
	migration.destinationVersion = 1;
	migration.migrationBlock = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			[newItem setValue: @"Untitled" forAttribute: @"label"];

			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};
	[COSchemaMigration registerMigration: migration];

	[ctx commit];
	[self prepareNewMigrationContextForDestinationVersion: 1];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);
	UKStringsEqual(@"Untitled", migratedParent.label);
	UKStringsEqual(@"Untitled", migratedChild.label);
	UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (void)testInsertOrUpdateItemsWithoutMigration
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

	[parentItem setVersion: 1 forDomain: @"Test"];

	UKRaisesException([parent.objectGraphContext insertOrUpdateItems: A(parentItem)]);
}
					  
- (void)testExceptionOnNegativeSchemaVersion
{
	COMutableItem *parentItem = [parent.storeItem mutableCopy];

	[parentItem setVersion: -1 forDomain: @"Test"];

	UKRaisesException([parent.objectGraphContext insertOrUpdateItems: A(parentItem)]);
}

- (void)testExceptionOnMissingMigration
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
	CORegisterCoreObjectMetamodel(repo);
	ETPackageDescription *testPackage = [repo descriptionForName: @"Test"];
	ETAssert(testPackage != nil);

	testPackage.version = 1;

	COMutableItem *childItem = [child.storeItem mutableCopy];
	COObjectGraphContext *migratedContext =
		[COObjectGraphContext objectGraphContextWithModelDescriptionRepository: repo];
	
	UKRaisesException([migratedContext insertOrUpdateItems: A(childItem)]);
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
