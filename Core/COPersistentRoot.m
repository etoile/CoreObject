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

@implementation COPersistentRoot

@synthesize parentContext = _parentContext;

- (ETUUID *)persistentRootUUID
{
    return _UUID;
}

- (id)initWithInfo: (COPersistentRootInfo *)info
     parentContext: (COEditingContext *)aCtxt
{
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
                                            persistentRoot: self
                                parentRevisionForNewBranch: nil] autorelease];
        
        [_branchForUUID setObject: branch forKey: branchUUID];
        
        ASSIGN(_currentBranchUUID, branchUUID);
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
    return [NSSet setWithArray: [_branchForUUID allValues]];
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
	NSArray *revs = [_parentContext commitWithMetadata: metadata
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
		ETAssert([[self insertedObjects] containsObject: [self rootObject]]);
        ETAssert([self editingBranch] != nil);
        ETAssert([self editingBranch] == [self currentBranch]);
        
        COPersistentRootInfo *info = [store createPersistentRootWithInitialContents: [[self editingBranch] objectGraph]
                                                                               UUID: [self persistentRootUUID]
                                                                         branchUUID: [[self editingBranch] UUID]
                                                                           metadata: metadata
                                                                              error: NULL];
        revId = [[info currentBranchInfo] currentRevisionID];
        
        // N.B., we don't call -saveCommitWithMetadata: on the branch,
        // because the store call -createPersistentRootWithInitialContents:
        // handles creating the initial branch.
        
        [[self editingBranch] didMakeInitialCommitWithRevisionID: [[info currentBranchInfo] currentRevisionID]];
	}
    else
    {
        // Commit a change to the current branch, if needed.
        if (![[_savedState currentBranchUUID] isEqual: _currentBranchUUID])
        {
            [store setCurrentBranch: _currentBranchUUID
               forPersistentRoot: [self persistentRootUUID]
                           error: NULL];
        }
        
        // Commit changes in our branches
        for (COBranch *branch in [self branches])
        {
            [branch saveCommitWithMetadata: metadata];
            
            // FIXME: Hack?
            [self reloadPersistentRootInfo];
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

- (void) addBranch: (COBranch*)aBranch
{
    [_branchForUUID addObject: aBranch forKey: [aBranch UUID]];
}

- (CORevision *) revision
{
    return [[self editingBranch] currentRevision];
}

- (void) setRevision:(CORevision *)revision
{
    [[self editingBranch] setCurrentRevision: revision];
}

@end
