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

- (void)prepareNewMigrationContextForDestinationVersions: (NSDictionary *)versionsByDomain
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
	CORegisterCoreObjectMetamodel(repo);

	for (NSString *domain in versionsByDomain)
	{
		ETPackageDescription *package = [repo descriptionForName: domain];
		ETAssert(package != nil);
		
		package.version = [versionsByDomain[domain] longLongValue];
	}

	migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
	                            modelDescriptionRepository: repo];
}

- (void)prepareNewMigrationContextForDestinationVersion: (int64_t)version
{
	[self prepareNewMigrationContextForDestinationVersions: @{@"Test" : @(version)}];
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

- (COSchemaMigration *)registerMigrationWithVersion: (int64_t)version
                                             domain: (NSString *)domain
                                              block: (COMigrationBlock)block
{
	COSchemaMigration *migration = [COSchemaMigration new];
	
	migration.domain = domain;
	migration.destinationVersion = version;
	migration.migrationBlock = block;
	
	[COSchemaMigration registerMigration: migration];
	return migration;
}

- (COSchemaMigration *)registerMigrationWithVersion: (int64_t)version
                                             domain: (NSString *)domain
{
	return [self registerMigrationWithVersion: version domain: domain block: NULL];
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

- (id)registerLabelUpdateMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
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

	return [self registerMigrationWithVersion: version domain: @"Test" block: block];
}

- (void)testBasicMigrationWithoutMetamodelChanges
{
	COSchemaMigration *migration = [self registerLabelUpdateMigrationWithVersion: 1];

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

- (id)registerNameUpdateMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			[newItem setValue: @"Unknown" forAttribute: @"name"];

			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"org.etoile-project.CoreObject"
	                                    block: block];
}

- (void)testBasicMigrationInTwoDomainsWithoutMetamodelChanges
{
	COSchemaMigration *testMigration = [self registerLabelUpdateMigrationWithVersion: 1];
	COSchemaMigration *coreObjectMigration = [self registerNameUpdateMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextForDestinationVersions:
		@{@"Test" : @(1), @"org.etoile-project.CoreObject" : @(1)}];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKStringsEqual(@"Unknown", migratedParent.name);
	UKStringsEqual(@"Unknown", migratedChild.name);
	UKStringsEqual(@"Untitled", migratedParent.label);
	UKStringsEqual(@"Untitled", migratedChild.label);

	UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

@end
