#import "COSynchronizerRevision.h"
#import "COStoreTransaction.h"

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

- (id) initWithUUID: (ETUUID *)aUUID persistentRoot: (ETUUID *)aPersistentRoot store: (COSQLiteStore *)store
{
	SUPERINIT;
	
	CORevisionInfo *info = [store revisionInfoForRevisionUUID: aUUID persistentRootUUID: aPersistentRoot];
	COItemGraph *graph = [store itemGraphForRevisionUUID: aUUID persistentRoot: aPersistentRoot];
	
	self.modifiedItems = graph;
	self.revisionUUID = aUUID;
	self.parentRevisionUUID = info.parentRevisionUUID;
	self.metadata = info.metadata;
	self.date = info.date;
	
	return self;
}

@end
