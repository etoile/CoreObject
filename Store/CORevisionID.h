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
    int64_t revisionIndex_;
}

+ (CORevisionID *) revisionWithBackinStoreUUID: (ETUUID *)aUUID
                                 revisionIndex: (int64_t)anIndex;

- (id) initWithPersistentRootBackingStoreUUID: (ETUUID *)aUUID
                                revisionIndex: (int64_t)anIndex;

- (ETUUID *) backingStoreUUID;
- (int64_t) revisionIndex;
/**
 * Returns a new CORevisionID with the stame backing store UUID but the given revid
 */
- (CORevisionID *) revisionIDWithRevisionIndex: (int64_t)anIndex;

- (id) plist;
+ (CORevisionID *) revisionIDWithPlist: (id)plist;

@end
