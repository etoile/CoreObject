#import "COStoreTransaction.h"

#import "COStoreSetCurrentBranch.h"
#import "COStoreCreateBranch.h"
#import "COStoreCreatePersistentRoot.h"
#import "COStoreSetCurrentRevision.h"
#import "COStoreSetBranchMetadata.h"
#import "COStoreDeletePersistentRoot.h"
#import "COStoreUndeletePersistentRoot.h"
#import "COStoreSetPersistentRootMetadata.h"
#import "COStoreDeleteBranch.h"
#import "COStoreUndeleteBranch.h"
#import "COStoreWriteRevision.h"
#import "COStoreAction.h"

@interface COStoreTransaction ()
@property (nonatomic, readwrite, strong) NSMutableArray *operations;
@end


@implementation COStoreTransaction

@synthesize operations;

- (id) init
{
    SUPERINIT;
    self.operations = [NSMutableArray arrayWithCapacity: 16];
	_oldTransactionIDForPersistentRootUUID = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) addOperation: (id)anOperation
{
    [operations addObject: anOperation];
}

- (NSArray *) persistentRootUUIDs
{
	NSMutableSet *results = [[NSMutableSet alloc] init];
	for (id <COStoreAction> action in operations)
	{
		[results addObject: action.persistentRoot];
	}
	return [results allObjects];
}

- (BOOL) touchesMutableStateForPersistentRootUUID: (ETUUID *)aUUID
{
	for (id <COStoreAction> action in operations)
	{
		if ([action.persistentRoot isEqual: aUUID]
			&& ![action isKindOfClass: [COStoreWriteRevision class]])
		{
			return YES;
		}
	}
	return NO;
}

/** @taskunit Transaction ID */

- (int64_t) oldTransactionIDForPersistentRoot: (ETUUID *)aPersistentRoot
{
	return [_oldTransactionIDForPersistentRootUUID[aPersistentRoot] longLongValue];
}

- (int64_t) setOldTransactionID: (int64_t)oldID forPersistentRoot: (ETUUID *)aPersistentRoot
{
	_oldTransactionIDForPersistentRootUUID[aPersistentRoot] = @(oldID);
	return oldID + 1;
}

/** @taskunit Revision Writing */

- (void) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch
{
    NILARG_EXCEPTION_TEST(anItemTree);
    NILARG_EXCEPTION_TEST([anItemTree rootItemUUID]);
    NSParameterAssert([aRevisionUUID isKindOfClass: [ETUUID class]]);
    NSParameterAssert(aParent == nil || [aParent isKindOfClass: [ETUUID class]]);
	NSParameterAssert(aMergeParent == nil || [aMergeParent isKindOfClass: [ETUUID class]]);
    NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    NSParameterAssert([branch isKindOfClass: [ETUUID class]]);
    
    COStoreWriteRevision *op = [[COStoreWriteRevision alloc] init];
    op.modifiedItems = anItemTree;
    op.revisionUUID = aRevisionUUID;
    op.metadata = metadata;
    op.parentRevisionUUID = aParent;
    op.mergeParentRevisionUUID = aMergeParent;
    op.persistentRoot = aUUID;
    op.branch = branch;
    [self addOperation: op];
}

/** @taskunit Persistent Root Creation */

- (void) createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
                persistentRootForCopy: (ETUUID *)persistentRootForCopyUUID
{
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    
    COStoreCreatePersistentRoot *op = [[COStoreCreatePersistentRoot alloc] init];
    op.persistentRoot = persistentRootUUID;
    op.persistentRootForCopy = persistentRootForCopyUUID;
    [self addOperation: op];
}

/**
 * Convenience method
 */
- (COPersistentRootInfo *) createPersistentRootCopyWithUUID: (ETUUID *)uuid
								   parentPersistentRootUUID: (ETUUID *)aParentPersistentRoot
												 branchUUID: (ETUUID *)aBranchUUID
										   parentBranchUUID: (ETUUID *)aParentBranch
										initialRevisionUUID: (ETUUID *)aRevision
{
    [self createPersistentRootWithUUID: uuid
				 persistentRootForCopy: aParentPersistentRoot];
    
    [self createBranchWithUUID: aBranchUUID
				  parentBranch: aParentBranch
			   initialRevision: aRevision
			 forPersistentRoot: uuid];
    
    [self setCurrentBranch: aBranchUUID
		 forPersistentRoot: uuid];
	
    COPersistentRootInfo *plist = [[COPersistentRootInfo alloc] init];
    plist.UUID = uuid;
    plist.deleted = NO;
    
    if (aBranchUUID != nil)
    {
        COBranchInfo *branch = [[COBranchInfo alloc] init];
        branch.UUID = aBranchUUID;
        branch.initialRevisionUUID = aRevision;
        branch.currentRevisionUUID = aRevision;
        branch.headRevisionUUID = aRevision;
        branch.metadata = nil;
        branch.deleted = NO;
        branch.parentBranchUUID = aParentBranch;
		
        plist.currentBranchUUID = aBranchUUID;
        plist.branchForUUID = @{aBranchUUID : branch};
    }
    
    return plist;
}

/**
 * Convenience method
 */
- (COPersistentRootInfo *) createPersistentRootWithInitialItemGraph: (COItemGraph *)contents
                                                               UUID: (ETUUID *)persistentRootUUID
                                                         branchUUID: (ETUUID *)aBranchUUID
                                                   revisionMetadata: (NSDictionary *)metadata
{
    NILARG_EXCEPTION_TEST(contents);
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    NILARG_EXCEPTION_TEST(aBranchUUID);
    
	ETUUID *revisionUUID = [ETUUID UUID];
	
	[self writeRevisionWithModifiedItems: contents
							revisionUUID: revisionUUID
								metadata: metadata
						parentRevisionID: nil
				   mergeParentRevisionID: nil
					  persistentRootUUID: persistentRootUUID
							  branchUUID: aBranchUUID];
    
    return [self createPersistentRootCopyWithUUID: persistentRootUUID
						 parentPersistentRootUUID: nil
									   branchUUID: aBranchUUID
								 parentBranchUUID: nil
							  initialRevisionUUID: revisionUUID];
}

/** @taskunit Persistent Root Modification */

- (void) setCurrentBranch: (ETUUID *)aBranch
        forPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetCurrentBranch *op = [[COStoreSetCurrentBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];
}

- (void) createBranchWithUUID: (ETUUID *)branchUUID
				 parentBranch: (ETUUID *)aParentBranch
              initialRevision: (ETUUID *)revId
            forPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(branchUUID);
    NILARG_EXCEPTION_TEST(revId);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreCreateBranch *op = [[COStoreCreateBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = branchUUID;
	op.parentBranch = aParentBranch;
    op.initialRevision = revId;
    [self addOperation: op];
}

/**
 * All-in-one method for updating the current revision of a persistent root.
 */
- (void) setCurrentRevision: (ETUUID *)currentRev
			   headRevision: (ETUUID *)headRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(currentRev);
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetCurrentRevision *op = [[COStoreSetCurrentRevision alloc] init];
    op.currentRevision = currentRev;
	op.headRevision = headRev;
    op.branch = aBranch;
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

- (void) setMetadata: (NSDictionary *)metadata
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetBranchMetadata *op = [[COStoreSetBranchMetadata alloc] init];
    op.metadata = metadata;
    op.branch = aBranch;
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

- (void) setMetadata: (NSDictionary *)metadata
   forPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreSetPersistentRootMetadata *op = [[COStoreSetPersistentRootMetadata alloc] init];
    op.metadata = metadata;
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/** @taskunit Persistent Root Deletion */

- (void) deletePersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreDeletePersistentRoot *op = [[COStoreDeletePersistentRoot alloc] init];
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/**
 * Unmarks the given persistent root as deleted
 */
- (void) undeletePersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreUndeletePersistentRoot *op = [[COStoreUndeletePersistentRoot alloc] init];
    op.persistentRoot = aRoot;
    [self addOperation: op];
}

/**
 * Marks the given branch of the persistent root as deleted, can be reverted by -undeleteBranch:ofPersistentRoot:.
 * Will be permanently removed when -finalizeDeletionsForPersistentRoot: is called.
 */
- (void) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreDeleteBranch *op = [[COStoreDeleteBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];
}

/**
 * Unmarks the given branch of a persistent root as deleted
 */
- (void) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    COStoreUndeleteBranch *op = [[COStoreUndeleteBranch alloc] init];
    op.persistentRoot = aRoot;
    op.branch = aBranch;
    [self addOperation: op];    
}

@end
