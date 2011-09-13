#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COStore;

@interface CORevision : NSObject <ETCollection>
{
	COStore *store;
	uint64_t revisionNumber;
}

- (COStore *)store;

- (uint64_t)revisionNumber;
- (ETUUID *)UUID;

- (NSDictionary *)metadata;

- (NSArray *)changedObjectUUIDs;
- (NSDictionary *)valuesAndPropertiesForObject: (ETUUID*)object;

/* Private */

- (id)initWithStore: (COStore *)aStore revisionNumber: (uint64_t)anID;

@end