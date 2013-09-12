/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "CORevision.h"
#import "FMDatabase.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation CORevision

+ (void) initialize
{
	if (self != [CORevision class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (CORevision *) revisionWithStore: (COSQLiteStore *)aStore revisionID: (CORevisionID *)anID
{
    CORevisionInfo *revInfo = [aStore revisionInfoForRevisionID: anID];
    
    return [[CORevision alloc] initWithStore: aStore
                                 revisionInfo: revInfo];
}

- (id)initWithStore: (COSQLiteStore *)aStore
       revisionInfo: (CORevisionInfo *)aRevInfo
{
	SUPERINIT;
	store =  aStore;
	revisionInfo =  aRevInfo;
	return self;
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [CORevision class]] == NO)
		return NO;

	return ([revisionInfo isEqual: ((CORevision *)rhs)->revisionInfo]
		&& [[store URL] isEqual: [[rhs store] URL]]);
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"revisionNumber", @"UUID", @"date", @"type", @"shortDescription", 
		@"longDescription", @"objectUUID", @"metadata", @"changedObjectUUIDs")];
}

- (COSQLiteStore *)store
{
	return store;
}

- (CORevisionID *)revisionID
{
	return [revisionInfo revisionID];
}

- (CORevision *)parentRevision
{
    if ([revisionInfo parentRevisionID] == nil)
    {
        return nil;
    }
    
	CORevisionInfo *parentRevInfo = [store revisionInfoForRevisionID: [revisionInfo parentRevisionID]];
	return [[[self class] alloc] initWithStore: store revisionInfo: parentRevInfo];
}

- (ETUUID *)persistentRootUUID
{
	// TODO: Implement it in the metadata for the new store
	return [ETUUID UUIDWithString: [[self metadata] objectForKey: @"persistentRootUUID"]];
}

- (ETUUID *)branchUUID
{
	// TODO: Implement it in the metadata for the new store
	return [ETUUID UUIDWithString: [[self metadata] objectForKey: @"commitTrackUUID"]];
}

- (NSDate *)date
{
	// TODO: Implement it in the metadata for the new store
	return [[self metadata] objectForKey: @"date"];
}

- (NSString *)type
{
	// TODO: Implement it in the metadata for the new store
	// Formalize the concept of similar operations belonging to a common kind...
	// For example:
	// - major edit vs minor edit
	// - Item Mutation that includes Add Item, Remove Item, Insert Item etc.
	return [[self metadata] objectForKey: @"type"];
}

- (NSString *)shortDescription;
{
	return [[self metadata] objectForKey: @"shortDescription"];
}

- (NSString *)longDescription
{
	return [[self metadata] objectForKey: @"longDescription"];
}

- (NSDictionary *)metadata
{
	return [revisionInfo metadata];
}

// TODO: Migrate the code below to the new store or reimplement similar ideas.

#if 0
- (NSArray *)changedObjectUUIDs
{
	NSMutableSet *result = [NSMutableSet set];
	FMResultSet *rs = [store->db executeQuery: @"SELECT objectuuid FROM commits WHERE revisionnumber = ?",
					   [NSNumber numberWithUnsignedLongLong: revisionNumber]];
	while ([rs next])
	{
		[result addObject: [store UUIDForKey: [rs longLongIntForColumnIndex: 0]]];
	}
	[rs close];
	return [result allObjects];
}

- (NSArray *)changedPropertiesForObjectUUID: (ETUUID *)objectUUID
{
	NSMutableArray *result = [NSMutableArray array];
	FMResultSet *rs = [store->db executeQuery: @"SELECT property FROM commits WHERE revisionnumber = ? AND objectuuid = ?",
					   [NSNumber numberWithUnsignedLongLong: revisionNumber],
					   [store keyForUUID: objectUUID]];

	while ([rs next])
	{
		[result addObject: [store propertyForKey: [rs longLongIntForColumnIndex: 0]]];
	}
	[rs close];

	return result;
}

- (NSString *)formattedChangedPropertiesForObjectUUID: (ETUUID *)objectUUID
{
	NSArray *changedProperties = [self changedPropertiesForObjectUUID: objectUUID];
	NSMutableString *description = [NSMutableString string];
	BOOL isList = NO;

	for (NSString *property in changedProperties)
	{
		if (isList)
		{
			[description appendString: @", "];
		}
		[description appendString: property];
		isList = YES;
	}

	return description;
}

- (NSArray *)changedObjectRecords
{
	NSMutableArray *objRecords = [NSMutableArray array];

	for (ETUUID *objectUUID in [self changedObjectUUIDs])
	{
		NSString *changedProperties = [self formattedChangedPropertiesForObjectUUID: objectUUID];
		CORecord *record = AUTORELEASE([[CORecord alloc] initWithDictionary: 
			D(objectUUID, @"objectUUID", changedProperties, @"properties")]);

		[objRecords addObject: record];
	}

	return objRecords;
}

- (id)content
{
	return 	[self changedObjectRecords];
}

- (NSArray *)contentArray
{
	return [NSArray arrayWithArray: [self changedObjectRecords]];
}

#endif

- (NSString *)description
{
	// FIXME: Test if the parent revision is the first revision ever made to the
	// store correctly. For now we test nil, but this probably doesn't make
	// sense for the new store.
	// Could be better to print the parent revision ID rather than the
	// parent revision objects, if the description is too verbose.
	return [NSString stringWithFormat: @"%@ (%@ <= %@)", 
		NSStringFromClass([self class]),
		[self revisionID],
		([self parentRevision] != nil ? [NSString stringWithFormat: @"%@", [self parentRevision]] : @"root")];
}

@end
