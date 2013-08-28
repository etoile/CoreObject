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
{
    ETUUID *backingStoreUUID_;
    ETUUID *revisionUUID_;
}

+ (CORevisionID *) revisionWithBackinStoreUUID: (ETUUID *)aUUID
                                  revisionUUID: (ETUUID *)revUUID;

- (id) initWithPersistentRootBackingStoreUUID: (ETUUID *)aUUID
                                 revisionUUID: (ETUUID *)revUUID;

@property (readonly, nonatomic) ETUUID *backingStoreUUID;
@property (readonly, nonatomic) ETUUID *revisionUUID;

/**
 * Returns a new CORevisionID with the stame backing store UUID but the given revid
 */
- (CORevisionID *) revisionIDWithRevisionUUID: (ETUUID *)revUUID;

- (id) plist;
+ (CORevisionID *) revisionIDWithPlist: (id)plist;

@end
