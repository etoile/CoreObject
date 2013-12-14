/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerRevision.h"
#import "COStoreTransaction.h"
#import "CODateSerialization.h"
@implementation COSynchronizerRevision

@synthesize modifiedItems, revisionUUID, parentRevisionUUID, metadata, date;

- (void) writeToTransaction: (COStoreTransaction *)txn
		 persistentRootUUID: (ETUUID *)persistentRoot
				 branchUUID: (ETUUID *)branch
{
	[txn writeRevisionWithModifiedItems: self.modifiedItems
						   revisionUUID: self.revisionUUID
							   metadata: self.metadata
					   parentRevisionID: self.parentRevisionUUID
				  mergeParentRevisionID: nil
					 persistentRootUUID: persistentRoot
							 branchUUID: branch];
}

- (id) initWithUUID: (ETUUID *)aUUID persistentRoot: (ETUUID *)aPersistentRoot store: (COSQLiteStore *)store recordAsDeltaAgainstParent: (BOOL)delta
{
	SUPERINIT;
	
	CORevisionInfo *info = [store revisionInfoForRevisionUUID: aUUID persistentRootUUID: aPersistentRoot];

	if (delta)
	{
		self.modifiedItems = [store partialItemGraphFromRevisionUUID: info.parentRevisionUUID toRevisionUUID: aUUID persistentRoot: aPersistentRoot];
	}
	else
	{
		self.modifiedItems = [store itemGraphForRevisionUUID: aUUID persistentRoot: aPersistentRoot];
	}
	
	self.revisionUUID = aUUID;
	self.parentRevisionUUID = info.parentRevisionUUID;
	self.metadata = info.metadata;
	self.date = info.date;
	
	return self;
}

- (id) propertyList
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	result[@"modifiedItems"] = COItemGraphToJSONPropertyList(self.modifiedItems);
	result[@"revisionUUID"] = [self.revisionUUID stringValue];
	if (self.parentRevisionUUID != nil)
	{
		result[@"parentRevisionUUID"] = [self.parentRevisionUUID stringValue];
	}
	if (self.metadata != nil)
	{
		result[@"metadata"] = self.metadata;
	}
	result[@"date"] = CODateToJavaTimestamp(self.date);
	return result;
}

- (id) initWithPropertyList: (id)aPropertyList
{
	SUPERINIT;
	self.modifiedItems = COItemGraphFromJSONPropertyLisy(aPropertyList[@"modifiedItems"]);
	self.revisionUUID = [ETUUID UUIDWithString: aPropertyList[@"revisionUUID"]];
	self.parentRevisionUUID = aPropertyList[@"parentRevisionUUID"] != nil
		? [ETUUID UUIDWithString: aPropertyList[@"parentRevisionUUID"]] : nil;
	self.metadata = aPropertyList[@"metadata"];
	self.date = CODateFromJavaTimestamp(aPropertyList[@"date"]);
	return self;
}

@end
