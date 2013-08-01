/*
	Copyright (C) 2012 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>, 
	         Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2012
	License:  Modified BSD  (see COPYING)
 */

#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COItem.h"
#import "COObject.h"
#import "COObjectGraphContext.h"
#import "CORelationshipCache.h"
#import "CORevision.h"
#import "COSerialization.h"
#import "COSQLiteStore.h"
#import "COCrossPersistentRootReferenceCache.h"

@implementation COPersistentRoot

@synthesize parentContext = _parentContext;

- (ETUUID *)persistentRootUUID
{
    return _UUID;
}

- (id) initWithInfo: (COPersistentRootInfo *)info
cheapCopyRevisionID: (CORevisionID *)cheapCopyRevisionID
 objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
      parentContext: (COEditingContext *)aCtxt
{
	if (info != nil)
    {
		INVALIDARG_EXCEPTION_TEST(anObjectGrapContext, anObjectGraphContext == nil);
    }
	if (anObjectGraphContext != nil)
	{
		INVALIDARG_EXCEPTION_TEST(info, info == nil);
		INVALIDARG_EXCEPTION_TEST(anObjectGraphContext, [anObjectGraphContext branch] == nil);
	}
	NILARG_EXCEPTION_TEST(aCtxt);

	SUPERINIT;
    
    _parentContext = aCtxt;
    ASSIGN(_savedState, info);
    _branchForUUID = [[NSMutableDictionary alloc] init];
    
    if (_savedState != nil)
    {
        ASSIGN(_UUID, [_savedState UUID]);
        
        for (COBranchInfo *branchInfo in [[_savedState branchForUUID] allValues])
        {
            COBranch *branch = [[[COBranch alloc] initWithUUID: [branchInfo UUID]
			                                objectGraphContext: nil
                                                persistentRoot: self
                                    parentRevisionForNewBranch: nil] autorelease];
            
            [_branchForUUID setObject: branch forKey: [branchInfo UUID]];
        }
        
        ASSIGN(_currentBranchUUID, [_savedState currentBranchUUID]);
    }
    else
    {
        ASSIGN(_UUID, [ETUUID UUID]);
        
        ETUUID *branchUUID = [ETUUID UUID];
        
        COBranch *branch = [[[COBranch alloc] initWithUUID: branchUUID
		                                objectGraphContext: anObjectGraphContext
                                            persistentRoot: self
                                parentRevisionForNewBranch: cheapCopyRevisionID] autorelease];
        
        [_branchForUUID setObject: branch forKey: branchUUID];
        
        ASSIGN(_currentBranchUUID, branchUUID);
        
        ASSIGN(_cheapCopyRevisionID, cheapCopyRevisionID);
    }

	return self;
}

- (void)dealloc
{
	DESTROY(_savedState);
	DESTROY(_branchForUUID);
    DESTROY(_currentBranchUUID);
	DESTROY(_editingBranchUUID);  
	[super dealloc];
}

#if 0
- (NSString *)description
{
	// TODO: Improve the indenting
	NSString *desc = [D([self insertedObjects], @"Inserted Objects",
	                    [self deletedObjects], @"Deleted Objects",
	                    _updatedPropertiesByObject, @"Updated Objects") description];
	/* For Mac OS X, see http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html */
	return [desc stringByReplacingOccurrencesOfString: @"\\n" withString: @"\n"];
}
#endif

- (BOOL)isPersistentRoot
{
	return YES;
}

- (BOOL)isEditingContext
{
	return NO;
}

- (COEditingContext *)editingContext
{
	return [self parentContext];
}

- (BOOL)isDeleted
{
    if ([[_parentContext persistentRootsPendingUndeletion] containsObject: self])
        return NO;
    
    if ([[_parentContext persistentRootsPendingDeletion] containsObject: self])
        return YES;
    
    if ([[_parentContext deletedPersistentRoots] containsObject: self])
        return YES;    
    
    return NO;
}

- (void) setDeleted:(BOOL)deleted
{
    if (deleted)
    {
        [_parentContext deletePersistentRoot: self];
    }
    else
    {
        [_parentContext undeletePersistentRoot: self];
    }
}

- (COBranch *)currentBranch
{
	return [_branchForUUID objectForKey: _currentBranchUUID];
}

- (void)setCurrentBranch: (COBranch *)aTrack
{
    if (![self isPersistentRootCommitted])
    {
        [NSException raise: NSGenericException format: @"A persistent root must be committed before you can add or change its branches"];
    }

    ASSIGN(_currentBranchUUID, [aTrack UUID]);
    
    [self updateCrossPersistentRootReferences];
}

- (COBranch *)editingBranch
{
    if (_editingBranchUUID == nil)
    {
        return [self currentBranch];
    }
    
	return [_branchForUUID objectForKey: _editingBranchUUID];
}

- (void)setEditingBranch: (COBranch *)aTrack
{
    if (![self isPersistentRootCommitted])
    {
        [NSException raise: NSGenericException format: @"A persistent root must be committed before you can add or change its branches"];
    }

    ASSIGN(_editingBranchUUID, [aTrack UUID]);
}

- (NSSet *)branches
{
    return [NSSet setWithArray: [[_branchForUUID allValues] filteredCollectionWithBlock:
                                        ^(id obj) { return (BOOL)![obj isDeleted]; }]];
}

- (NSSet *)deletedBranches
{
    return [NSSet setWithArray: [[_branchForUUID allValues] filteredCollectionWithBlock:
                                 ^(id obj) { return [obj isDeleted]; }]];
}

- (NSSet *)insertedBranches
{
    return [[self branches] filteredCollectionWithBlock:
            ^(id obj) { return [obj isBranchUncommitted]; }];
}

- (COBranch *)branchForUUID: (ETUUID *)aUUID
{
    return [_branchForUUID objectForKey: aUUID];
}

- (void) deleteBranch: (COBranch *)aBranch
{
    [aBranch setDeleted: YES];
    
    if ([aBranch isBranchUncommitted])
    {
        [_branchForUUID removeObjectForKey: [aBranch UUID]];
        return;
    }
}

- (COObjectGraphContext *)objectGraph
{
    return [[self editingBranch] objectGraph];
}

- (COSQLiteStore *)store
{
	return [_parentContext store];
}

- (id)rootObject
{
	return [[self objectGraph] rootObject];
}

- (void)setRootObject: (COObject *)aRootObject
{
	[[self objectGraph] setRootObject: aRootObject];
}

- (ETUUID *)rootObjectUUID
{
	return [[self objectGraph] rootItemUUID];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid
{
	return [[self objectGraph] objectWithUUID: uuid];
}

- (NSSet *)loadedObjects
{
    return [NSSet setWithArray: [[self objectGraph] allObjects]];
}

- (NSSet *)loadedObjectUUIDs
{
	return [NSSet setWithArray: [[self objectGraph] itemUUIDs]];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *loadedRootObjects = [NSMutableSet setWithSet: [self loadedObjects]];
	[[loadedRootObjects filter] isRoot];
	return loadedRootObjects;
}

- (id)loadedObjectForUUID: (ETUUID *)uuid
{
	return [[self objectGraph] objectWithUUID: uuid];
}

- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID
{
    NSLog(@"-discardLoadedObjectForUUID: deprecated and has no effect");
}

- (NSSet *)insertedObjects
{
	return [[self objectGraph] insertedObjects];
}

- (NSSet *)updatedObjects
{
	return [[self objectGraph] updatedObjects];
}

- (NSSet *)updatedObjectUUIDs
{
	return [NSSet setWithArray: (id)[[[self updatedObjects] mappedCollection] UUID]];
}

- (BOOL)isUpdatedObject: (COObject *)anObject
{
	return [[self updatedObjects] containsObject: anObject];
}

- (NSMapTable *) updatedPropertiesByObject
{
	return [[self objectGraph] updatedPropertiesByObject];
}

- (NSSet *)changedObjects
{
    return [[self objectGraph] changedObjects];
}

- (NSSet *)changedObjectUUIDs
{
    return (NSSet *)[[[self changedObjects] mappedCollection] UUID];
}

- (void)discardAllChanges
{
	[[self editingBranch] discardAllChanges];
}

- (void)discardChangesInObject: (COObject *)object
{
    [[self editingBranch] discardChangesInObject: object];
}

- (BOOL)hasChanges
{
	return [[self changedObjects] count] > 0;
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName
                                    UUID: (ETUUID *)aUUID
{
	return [[self objectGraph] insertObjectWithEntityName: aFullName
                                               UUID: aUUID];
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
	return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID]];
}

- (CORevision *)commit
{
	return [self commitWithType: nil shortDescription: nil];
}

- (CORevision *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription
{
	NSString *commitType = type;
	
	if (type == nil)
	{
		commitType = @"Unknown";
	}
	if (shortDescription == nil)
	{
		shortDescription = @"";
	}
	return [self commitWithMetadata: D(shortDescription, @"shortDescription", commitType, @"type")];
}

- (CORevision *)commitWithMetadata: (NSDictionary *)metadata
{
	[_parentContext commitWithMetadata: metadata
	                restrictedToPersistentRoots: A(self)];
	//ETAssert([revs count] == 1);
	//return [revs lastObject];
    return nil;
}

- (BOOL) isPersistentRootCommitted
{
    return _savedState != nil;
}

- (void) saveCommitWithMetadata: (NSDictionary *)metadata
{
	ETAssert([[self rootObject] isRoot]);
    
	COSQLiteStore *store = [_parentContext store];
    CORevisionID *revId;
    
	if (![self isPersistentRootCommitted])
	{		
        ETAssert([self editingBranch] != nil);
        ETAssert([self editingBranch] == [self currentBranch]);
        
        COPersistentRootInfo *info;
        
        if (_cheapCopyRevisionID == nil)
        {
            info = [store createPersistentRootWithInitialContents: [[self editingBranch] objectGraph]
                                                                                   UUID: [self persistentRootUUID]
                                                                             branchUUID: [[self editingBranch] UUID]
                                                                               metadata: metadata
                                                                                  error: NULL];
        }
        else
        {
            info = [store createPersistentRootWithInitialRevision: _cheapCopyRevisionID
                                                             UUID: _UUID
                                                       branchUUID: [[self editingBranch] UUID]
                                                         metadata: metadata
                                                            error: NULL];
        }
        ETAssert(info != nil);
        
        revId = [[info currentBranchInfo] currentRevisionID];
        
        // N.B., we don't call -saveCommitWithMetadata: on the branch,
        // because the store call -createPersistentRootWithInitialContents:
        // handles creating the initial branch.
        
        [[self editingBranch] didMakeInitialCommitWithRevisionID: [[info currentBranchInfo] currentRevisionID]];
	}
    else
    {
        // Commit changes in our branches
        for (COBranch *branch in [self branches])
        {
            [branch saveCommitWithMetadata: metadata];
            
            // FIXME: Hack?
            [self reloadPersistentRootInfo];
        }
        
        // Commit a change to the current branch, if needed.
        // Needs to be done after because the above loop may create the branch
        if (![[_savedState currentBranchUUID] isEqual: _currentBranchUUID])
        {
            ETAssert([store setCurrentBranch: _currentBranchUUID
                           forPersistentRoot: [self persistentRootUUID]
                                       error: NULL]);
        }
    }

    // FIXME: Hack?
    [self reloadPersistentRootInfo];
}

- (Class)referenceClassForRootObject: (COObject *)aRootObject
{
	// TODO: When the user has selected a precise branch, just return COCommitTrack.
	return [COPersistentRoot class];
}

/** @taskunit Persistent root info */

- (COPersistentRootInfo *) persistentRootInfo
{
    return _savedState;
}

- (void) reloadPersistentRootInfo
{
    COPersistentRootInfo *newInfo = [[self store] persistentRootInfoForUUID: [self persistentRootUUID]];
    if (newInfo != nil)
    {
        ASSIGN(_savedState, newInfo);
    }
}


- (COBranch *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev
{
    COBranch *newBranch = [[[COBranch alloc] initWithUUID: [ETUUID UUID]
	                                   objectGraphContext: nil
                                           persistentRoot: self
                               parentRevisionForNewBranch: [aRev revisionID]] autorelease];
    
    [newBranch setMetadata: D(aLabel, @"COBranchLabel")];
    
    [_branchForUUID addObject: newBranch forKey: [newBranch UUID]];
    
    return newBranch;
}

- (CORevision *) revision
{
    return [[self editingBranch] currentRevision];
}

- (void) setRevision:(CORevision *)revision
{
    [[self editingBranch] setCurrentRevision: revision];
}

- (void)storePersistentRootDidChange: (NSNotification *)notif
{
    COPersistentRootInfo *info = [[self store] persistentRootInfoForUUID: [self persistentRootUUID]];
    
    // FIXME: This is really incomplete... factor out into a persistent root merge method.
    
    for (ETUUID *uuid in [info branchUUIDs])
    {
        COBranchInfo *branchInfo = [info branchInfoForUUID: uuid];
        
        // FIXME: Don't use the user method -setCurrentRevision: because it might mark the branch as neededing to be committed!
        [[self branchForUUID: uuid] setCurrentRevision: [CORevision revisionWithStore: [self store] revisionID: [branchInfo currentRevisionID]]];
    }
}

- (void)updateCrossPersistentRootReferences
{
    NSArray *objs = [[_parentContext crossReferenceCache] affectedObjectsForChangeInPersistentRoot: [self persistentRootUUID]];
    
    for (COObject *obj in objs)
    {
        [obj updateCrossPersistentRootReferences];
    }
    
    // TODO: May need something like this?
//    for (COBranch *branch in [_branchForUUID allValues])
//    {
//        COObjectGraphContext *graph = [branch objectGraph];
//        for (COObject *obj in [graph allObjects])
//        {
//            NSArray *persistentRoots = [[_parentContext crossReferenceCache] referencedPersistentRootUUIDsForObject: obj];
//            for (ETUUID *persistentRootUUID in persistentRoots)
//            {
//                COPersistentRoot *persistentRoot = [_parentContext persistentRootForUUID: persistentRootUUID];
//                for (COBranch *otherBranch in [persistentRoot->_branchForUUID allValues])
//                {
//                    COObjectGraphContext *otherGraph = [otherBranch objectGraph];
//                    [[otherGraph rootObject] updateCrossPersistentRootReferences];                    
//                }
//            }
//        }
//    }
}

@end
