/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "CORevision.h"
#import "COCommitDescriptor.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"
#import "CORevisionCache.h"


@implementation CORevision

- (id)initWithCache: (CORevisionCache *)aCache
       revisionInfo: (CORevisionInfo *)aRevInfo
{
	SUPERINIT;
	cache = aCache;
	revisionInfo =  aRevInfo;
    assert([revisionInfo revisionUUID] != nil);
	return self;
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [CORevision class]] == NO)
		return NO;

	return [revisionInfo.revisionUUID isEqual: ((CORevision *)rhs)->revisionInfo.revisionUUID];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"UUID", @"date", @"type", @"localizedTypeDescription",
		@"localizedShortDescription", @"metadata")];
}

- (ETUUID *)UUID
{
	return [revisionInfo revisionUUID];
}

- (CORevision *)parentRevision
{
    if ([revisionInfo parentRevisionUUID] == nil)
    {
        return nil;
    }
    
	ETUUID *parentRevID = [revisionInfo parentRevisionUUID];
    return [cache revisionForRevisionUUID: parentRevID
					   persistentRootUUID: [revisionInfo persistentRootUUID]];
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

- (COCommitDescriptor *)commitDescriptor
{
	NSString *commitDescriptorId =
		[[self metadata] objectForKey: kCOCommitMetadataIdentifier];

	if (commitDescriptorId == nil)
		return nil;

	return [COCommitDescriptor registeredDescriptorForIdentifier: commitDescriptorId];
}

- (NSString *)localizedTypeDescription
{
	COCommitDescriptor *descriptor = [self commitDescriptor];

	if (descriptor == nil)
		return [[self metadata] objectForKey: kCOCommitMetadataTypeDescription];

	return [descriptor localizedTypeDescription];
}

- (NSString *)localizedShortDescription
{
	COCommitDescriptor *descriptor = [self commitDescriptor];

	if (descriptor == nil)
		return [[self metadata] objectForKey: kCOCommitMetadataShortDescription];
	
	return [descriptor localizedShortDescriptionWithArguments:
		[[self metadata] objectForKey: kCOCommitMetadataShortDescriptionArguments]];
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
	return [NSString stringWithFormat: @"%@ (%@ <= %@)", 
		NSStringFromClass([self class]),
		[self UUID],
		([self parentRevision] != nil ? [[self parentRevision] UUID] : @"none")];
}

@end
