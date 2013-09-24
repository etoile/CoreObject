/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "CORevision.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"
#import "COEditingContext.h"
#import "COEditingContext+Private.h"
#import "CORevisionID.h"

@implementation CORevision

- (id)initWithEditingContext: (COEditingContext *)aContext
                revisionInfo: (CORevisionInfo *)aRevInfo
{
	SUPERINIT;
	editingContext = aContext;
	revisionInfo =  aRevInfo;
    assert([revisionInfo revisionID] != nil);
	return self;
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [CORevision class]] == NO)
		return NO;

	return [revisionInfo.revisionID.revisionUUID isEqual: ((CORevision *)rhs)->revisionInfo.revisionID.revisionUUID];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"revisionNumber", @"UUID", @"date", @"type", @"shortDescription", 
		@"longDescription", @"objectUUID", @"metadata", @"changedObjectUUIDs")];
}

- (COEditingContext *)editingContext
{
	return editingContext;
}

- (CORevisionID *)revisionID
{
    assert([revisionInfo revisionID] != nil);
	return [revisionInfo revisionID];
}

- (ETUUID *)UUID
{
	return [[self revisionID] revisionUUID];
}

- (CORevision *)parentRevision
{
    if ([revisionInfo parentRevisionID] == nil)
    {
        return nil;
    }
    
	CORevisionID *parentRevID = [revisionInfo parentRevisionID];
    return [editingContext revisionForRevisionID: parentRevID];
}

- (ETUUID *)persistentRootUUID
{
	return [revisionInfo persistentRootUUID];
}

- (ETUUID *)branchUUID
{
	return [revisionInfo branchUUID];
}

- (NSDate *)date
{
	return [revisionInfo date];
}

// TODO: Implement it in the metadata for the new store
// Formalize the concept of similar operations belonging to a common kind...
// For example:
// - major edit vs minor edit
// - Item Mutation that includes Add Item, Remove Item, Insert Item etc.

- (NSDictionary *)metadata
{
	return [revisionInfo metadata];
}

- (NSString *)type
{
	return [[self metadata] objectForKey: @"type"];
}

- (NSString *)shortDescription;
{
	return [[self metadata] objectForKey: @"shortDescription"];
}

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
