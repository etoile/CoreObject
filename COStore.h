#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "FMDatabase.h"
#import "CORevision.h"

@interface COStore : NSObject
{
@package
	FMDatabase *db;
	NSURL *url;
	NSMutableDictionary *commitObjectForID;
	
	NSNumber *commitInProgress;
	ETUUID *objectInProgress;
}

- (id)initWithURL: (NSURL*)aURL;
- (NSURL*)URL;

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary*)meta;

- (void)beginChangesForObject: (ETUUID*)object;

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex;

- (void)finishChangesForObject: (ETUUID*)object;

- (CORevision*)finishCommit;

- (CORevision*)revisionWithRevisionNumber: (uint64_t)anID;

/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query;

/* Revision history */

- (uint64_t) latestRevisionNumber;

/* Private */

- (BOOL)setupDB;
- (NSNumber*)keyForUUID: (ETUUID*)uuid;
- (ETUUID*)UUIDForKey: (int64_t)key;
- (NSNumber*)keyForProperty: (NSString*)property;
- (NSString*)propertyForKey: (int64_t)key;

@end
