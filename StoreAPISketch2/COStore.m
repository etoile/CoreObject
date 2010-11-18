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
}

- (id)initWithURL: (NSURL*)aURL;
- (NSURL*)URL;

/* Named branches */

- (CONamedBranch*)createNamedBranch;
- (CONamedBranch*)namedBranchForUUID: (ETUUID*)uuid;

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary*)meta;

- (void)beginChangesForObject: (ETUUID*)object
				onNamedBranch: (ETUUID*)namedBranch
				 parentCommit: (ETUUID*)parent
				 mergedCommit: (ETUUID*)mergedBranch;

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex;

- (void)finishChangesForObject: (ETUUID*)object;

- (COCommit*)finishCommit;

/* Accessing History Graph and Committed Changes */

- (COCommit*)commitForUUID: (ETUUID*)aCommit;

/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query;

@end
