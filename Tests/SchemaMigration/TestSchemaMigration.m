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
	Tag *tag;
	OutlineItem *parent;
	OutlineItem *child;
}

@end

@implementation TestSchemaMigration

- (id)init
{
	[COSchemaMigration clearRegisteredMigrations];
	SUPERINIT;
	[self prepareNewContextWithModelDescriptionRepository: [ETModelDescriptionRepository mainRepository]];
	return self;
}

- (void)dealloc
{
	[COSchemaMigration clearRegisteredMigrations];
}

- (void)prepareNewContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	ctx = [[COEditingContext alloc] initWithStore: store
	                   modelDescriptionRepository: repo];
	tag = [ctx insertNewPersistentRootWithEntityName: @"Tag"].rootObject;
	parent = [[OutlineItem alloc] initWithObjectGraphContext: tag.objectGraphContext];
	child = [[OutlineItem alloc] initWithObjectGraphContext: parent.objectGraphContext];
	tag.contents = S(parent);
	[parent addObject: child];
}

- (ETModelDescriptionRepository *)validateModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	NSMutableArray *warnings = [NSMutableArray new];
	[repo checkConstraints: warnings];
	ETAssert([warnings isEmpty]);
	return repo;
}

- (ETModelDescriptionRepository *)modelDescriptionRepositoryForDestinationVersions: (NSDictionary *)versionsByDomain
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository new];
	CORegisterCoreObjectMetamodel(repo);

	for (NSString *domain in versionsByDomain)
	{
		ETPackageDescription *package = [repo descriptionForName: domain];
		ETAssert(package != nil);
		
		package.version = [versionsByDomain[domain] longLongValue];
	}
	return repo;
}

- (void)prepareNewMigrationContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	migrationCtx = [[COEditingContext alloc] initWithStore: ctx.store
								modelDescriptionRepository: repo];
}

- (void)prepareNewMigrationContextForDestinationVersions: (NSDictionary *)versionsByDomain
{
	[self prepareNewMigrationContextWithModelDescriptionRepository:
	 	[self modelDescriptionRepositoryForDestinationVersions: versionsByDomain]];
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
		OutlineItem *newParent = [(Tag *)testRootObject contents].anyObject;
		OutlineItem *newChild = [newParent.content firstObject];
	
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

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				[newItem setValue: @"Untitled" forAttribute: @"label"];
			}
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
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKNil(migratedTag.label);
	UKStringsEqual(@"Untitled", migratedParent.label);
	UKStringsEqual(@"Untitled", migratedChild.label);

	UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
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

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				[newItem setValue: @"Unknown" forAttribute: @"name"];
			}
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
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKNil(migratedTag.name);
	UKStringsEqual(@"Unknown", migratedParent.name);
	UKStringsEqual(@"Unknown", migratedChild.name);
	UKNil(migratedTag.label);
	UKStringsEqual(@"Untitled", migratedParent.label);
	UKStringsEqual(@"Untitled", migratedChild.label);

	UKObjectsEqual(S(migratedTag), migratedParent.parentCollections);
	UKObjectsEqual(migratedParent, migratedChild.parentContainer);
}

- (COSchemaMigration *)registerCommentAdditionMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				[newItem setValue: @"Type something"
				     forAttribute: @"comment"
				             type: kCOTypeString];
			}
			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerCommentAdditionInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(1), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
	ETPropertyDescription *comment = [ETPropertyDescription descriptionWithName: @"comment"];

	comment.type = [repo descriptionForName: @"NSString"];
	comment.persistent = YES;
	
	[outlineEntity addPropertyDescription: comment];
	[repo addDescription: comment];
	return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyAddition
{
	COSchemaMigration *testMigration = [self registerCommentAdditionMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerCommentAdditionInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKRaisesException([migratedTag valueForProperty: @"comment"]);
	UKStringsEqual(@"Type something", [migratedParent valueForProperty: @"comment"]);
	UKStringsEqual(@"Type something", [migratedChild valueForProperty: @"comment"]);
}

- (COSchemaMigration *)registerLabelDeletionMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				[newItem removeValueForAttribute: @"label"];
			}
			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerLabelDeletionInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(1), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
	ETPropertyDescription *label = [outlineEntity propertyDescriptionForName: @"label"];

	[repo removeDescription: label];
	[outlineEntity removePropertyDescription: label];
	return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyDeletion
{
	COSchemaMigration *testMigration = [self registerLabelDeletionMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerLabelDeletionInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKNil([migratedTag valueForProperty: @"label"]);
	UKRaisesException([migratedParent valueForProperty: @"label"]);
	UKRaisesException([migratedChild valueForProperty: @"label"]);
}

- (COSchemaMigration *)registerLabelRenamingMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				[newItem setValue: [oldItem valueForAttribute: @"label"]
				     forAttribute: @"title"
				             type: [oldItem typeForAttribute: @"label"]];
				[newItem removeValueForAttribute: @"label"];
			}
			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerLabelRenamingInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(1), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
	ETPropertyDescription *label = [outlineEntity propertyDescriptionForName: @"label"];

	// TODO: We should catch missing owner in -add/removeDescription: to prevent
	// ordering issues between -removeDescription: and -removePropertyDescriptions:
	[repo removeDescription: label];
	[outlineEntity removePropertyDescription: label];
	label.name = @"title";
	[outlineEntity addPropertyDescription: label];
	[repo addDescription: label];

	return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyRenaming
{
	COSchemaMigration *testMigration = [self registerLabelRenamingMigrationWithVersion: 1];

	parent.label = @"Zig";
	child.label = @"Zag";
	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerLabelRenamingInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];
	
	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);
	
	UKRaisesException([migratedTag valueForProperty: @"title"]);
	UKStringsEqual(parent.label, [migratedParent valueForProperty: @"title"]);
	UKStringsEqual(child.label, [migratedChild valueForProperty: @"title"]);
	UKNil([migratedTag valueForProperty: @"label"]);
	UKRaisesException([migratedParent valueForProperty: @"label"]);
	UKRaisesException([migratedChild valueForProperty: @"label"]);
}

- (COSchemaMigration *)registerNameOverridingMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			if ([newItem.entityName isEqualToString: @"OutlineItem"])
			{
				/* We insert some random value, but we could do nothing or
				   compute a derived value to initialize this overriden property
				   that takes over COObject.name */
				[newItem setValue: @"Overriden"
				     forAttribute: @"name"
				             type: kCOTypeString];
			}
			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerNameOverridingInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(1), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
	ETPropertyDescription *name = [ETPropertyDescription descriptionWithName: @"name"];

	name.type = [repo descriptionForName: @"NSString"];
	name.persistent = YES;

	[outlineEntity addPropertyDescription: name];
	[repo addDescription: name];
	return [self validateModelDescriptionRepository: repo];
}

- (void)testPropertyOverridingAccrossDomains
{
	COSchemaMigration *testMigration = [self registerNameOverridingMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerNameOverridingInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];
	
	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKNil(migratedTag.name);
	UKStringsEqual(@"Overriden", migratedParent.name);
	UKStringsEqual(@"Overriden", migratedChild.name);
}

- (COSchemaMigration *)registerOutlineMediaAdditionMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			COMutableItem *newItem = [oldItem mutableCopy];

			[newItem setVersion: migration.destinationVersion
			          forDomain: migration.domain];

			[migratedItems addObject: newItem];

			if (![newItem.entityName isEqualToString: @"OutlineItem"])
				continue;
	
			COMutableItem *mediaItem = [COMutableItem item];

			[mediaItem setValue: @"OutlineMedia"
			       forAttribute: kCOObjectEntityNameProperty
						   type: kCOTypeString];
			[mediaItem setValue: [oldItem valueForAttribute: kCOObjectDomainsProperty]
			       forAttribute: kCOObjectDomainsProperty
						   type: [oldItem typeForAttribute: kCOObjectDomainsProperty]];
			[mediaItem setValue: [oldItem valueForAttribute: kCOObjectVersionsProperty]
			       forAttribute: kCOObjectVersionsProperty
						   type: [oldItem typeForAttribute: kCOObjectVersionsProperty]];
			[mediaItem setVersion: migration.destinationVersion
				        forDomain: migration.domain];

			[newItem setValue: mediaItem.UUID
			     forAttribute: @"media"
			             type: kCOTypeReference];

			[migratedItems addObject: mediaItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerOutlineMediaAdditionInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(version), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *mediaEntity = [ETEntityDescription descriptionWithName: @"OutlineMedia"];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];
	ETPropertyDescription *media = [ETPropertyDescription descriptionWithName: @"media"];

	mediaEntity.owner = [repo descriptionForName: @"Test"];
	mediaEntity.parent = [repo descriptionForName: @"COObject"];

	// TODO: Detect missing/invalid type in a property description on
	// -[ETModelDescriptionRepository addDescription:]
	media.type = mediaEntity;
	media.persistent = YES;
	
	[outlineEntity addPropertyDescription: media];
	[repo addDescription: mediaEntity];
	[repo addDescription: media];
	return [self validateModelDescriptionRepository: repo];
}

- (void)testEntityAddition
{
	COSchemaMigration *testMigration = [self registerOutlineMediaAdditionMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerOutlineMediaAdditionInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];
	
	UKIntsEqual(0, [migratedTag.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedTag.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	ETEntityDescription *newEntity =
		[migratedContext.modelDescriptionRepository descriptionForName: @"OutlineMedia"];

	UKRaisesException([migratedTag valueForProperty: @"media"]);
	UKObjectsEqual(newEntity, [[migratedParent valueForProperty: @"media"] entityDescription]);
	UKObjectsEqual(newEntity, [[migratedChild valueForProperty: @"media"] entityDescription]);
	UKDoesNotRaiseException([migrationCtx insertNewPersistentRootWithEntityName: @"OutlineMedia"]);
}

- (COSchemaMigration *)registerTagDeletionMigrationWithVersion: (int64_t)version
{
	COMigrationBlock block = ^(COSchemaMigration *migration, NSArray *storeItems) {
		NSMutableArray *migratedItems = [NSMutableArray new];

		for (COMutableItem *oldItem in storeItems)
		{
			if ([oldItem.entityName isEqualToString: @"Tag"])
				continue;

			COMutableItem *newItem = [oldItem mutableCopy];
	
			[newItem setVersion: migration.destinationVersion
				      forDomain: migration.domain];

			[migratedItems addObject: newItem];
		}
		return migratedItems;
	};

	return [self registerMigrationWithVersion: version
	                                   domain: @"Test"
	                                    block: block];
}

- (ETModelDescriptionRepository *)registerTagDeletionInMetamodelWithVersion: (int64_t)version
{
	ETModelDescriptionRepository *repo = [self modelDescriptionRepositoryForDestinationVersions:
		@{@"Test" : @(version), @"org.etoile-project.CoreObject" : @(0)}];
	ETEntityDescription *tagEntity = [repo descriptionForName: @"Tag"];
	ETEntityDescription *outlineEntity = [repo descriptionForName: @"OutlineItem"];

	[repo removeDescription: tagEntity];
	return [self validateModelDescriptionRepository: repo];
}

- (void)testEntityDeletion
{
	COSchemaMigration *testMigration = [self registerTagDeletionMigrationWithVersion: 1];

	[ctx commit];
	[self prepareNewMigrationContextWithModelDescriptionRepository:
		[self registerTagDeletionInMetamodelWithVersion: 1]];

	COObjectGraphContext *migratedContext =
		[migrationCtx persistentRootForUUID: parent.persistentRoot.UUID].objectGraphContext;
	Tag *migratedTag = [migratedContext loadedObjectForUUID: tag.UUID];
	OutlineItem *migratedParent = [migratedContext loadedObjectForUUID: parent.UUID];
	OutlineItem *migratedChild = [migratedContext loadedObjectForUUID: child.UUID];

	UKIntsEqual(0, [migratedParent.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(0, [migratedChild.storeItem versionForDomain: @"org.etoile-project.CoreObject"]);
	UKIntsEqual(1, [migratedParent.storeItem versionForDomain: @"Test"]);
	UKIntsEqual(1, [migratedChild.storeItem versionForDomain: @"Test"]);

	UKNil(migratedTag);
	UKTrue(migratedParent.parentCollections.isEmpty);
	UKRaisesException([migrationCtx insertNewPersistentRootWithEntityName: @"Tag"]);
}

@end
