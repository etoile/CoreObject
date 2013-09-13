#import <Foundation/Foundation.h>

@class ETUUID;

/**
 * Store-global_ identifier for a COPersistentRootState.
 * It should be regarded as opaque, and only the store knows how to interpret it.
 *
 * 
 * Could be:
 *  - int64_t (store-global)
 *  - uuid (universally unique)
 *  - hash of contents (universally unique, guarantees data consistency)
 *
 * 
 */
@interface CORevisionID : NSObject <NSCopying>

+ (CORevisionID *) revisionWithPersistentRootUUID: (ETUUID *)aUUID
                                     revisionUUID: (ETUUID *)revUUID;

- (id) initWithPersistentRootUUID: (ETUUID *)aUUID
                     revisionUUID: (ETUUID *)revUUID;

@property (readonly, nonatomic) ETUUID *revisionPersistentRootUUID;
@property (readonly, nonatomic) ETUUID *revisionUUID;

/**
 * Returns a new CORevisionID with the stame persistent root UUID but the given revision UUID
 */
- (CORevisionID *) revisionIDWithRevisionUUID: (ETUUID *)revUUID;

- (id) plist;
+ (CORevisionID *) revisionIDWithPlist: (id)plist;

@end
