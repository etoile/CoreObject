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

/* Object State */

- (CONamedBranch*)activeBranchForObjectUUID: (ETUUID*)object;
- (void)setActiveBranch: (CONamedBranch*)branch forObjectUUID: (ETUUID*)object;
- (COCommit*)currentCommitForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (BOOL)setCurrentCommit: (COCommit*)commit forObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;
- (COCommit*)tipForObjectUUID: (ETUUID*)object onBranch: (CONamedBranch*)branch;

/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query;

/* Private */

- (BOOL)setupDB;
- (NSNumber*)keyForUUID: (ETUUID*)uuid;
- (ETUUID*)UUIDForKey: (int64_t)key;
- (NSNumber*)keyForProperty: (NSString*)property;
- (NSString*)propertyForKey: (int64_t)key;

@end
