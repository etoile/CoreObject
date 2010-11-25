#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "FMDatabase.h"
#import "CONamedBranch.h"
#import "COCommit.h"

@interface COStore : NSObject
{
@package
	FMDatabase *db;
	NSURL *url;
	NSMutableDictionary *commitObjectForUUID;
	NSMutableDictionary *branchObjectForUUID;
	
	ETUUID *commitInProgress;
	ETUUID *objectInProgress;
}

- (id)initWithURL: (NSURL*)aURL;
- (NSURL*)URL;

/* Named branches */

- (CONamedBranch*)createNamedBranch;
- (CONamedBranch*)namedBranchForUUID: (ETUUID*)uuid;

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary*)meta;

/**
 * The namedBranch paramater is stored in the commit metadata, so we never
 * lose track of which branch a commit was made on. Normally it will be
 * [parent namedBranch] unless this commit is initiating a new branch
 */
- (void)beginChangesForObject: (ETUUID*)object
				onNamedBranch: (CONamedBranch*)namedBranch
			updateObjectState: (BOOL)updateState
				 parentCommit: (COCommit*)parent
				 mergedCommit: (COCommit*)mergedBranch;

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex;

- (void)finishChangesForObject: (ETUUID*)object;

- (COCommit*)finishCommit;

/* Accessing History Graph and Committed Changes */

- (COCommit*)commitForUUID: (ETUUID*)aCommit;

/* Object State Access */

- (NSArray*)branchesForObjectUUID: (ETUUID*)object;
- (CONamedBranch*)activeBranchForObjectUUID: (ETUUID*)object;
- (ETUUID*)currentCommitForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (ETUUID*)tipForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (NSString*)entityNameForObjectUUID: (ETUUID*)object;

/* Object state modification */

// FIXME: currently each call is atomic, but we may want to batch up a group to be atomic

- (void)setActiveBranch: (CONamedBranch*)branch forObjectUUID: (ETUUID*)object;
- (BOOL)setCurrentCommit: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (BOOL)setTip: (ETUUID*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
/**
 * Note: the entity name of an object shouldn't be changed
 */
- (void)setEntityName: (NSString*)name forObjectUUID: (ETUUID*)object;


/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query;

/* Private */

- (BOOL)setupDB;
- (NSNumber*)keyForUUID: (ETUUID*)uuid;
- (ETUUID*)UUIDForKey: (int64_t)key;
- (NSNumber*)keyForProperty: (NSString*)property;
- (NSString*)propertyForKey: (int64_t)key;

@end
