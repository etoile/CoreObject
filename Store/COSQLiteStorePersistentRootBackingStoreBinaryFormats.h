/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;

NS_ASSUME_NONNULL_BEGIN

/**
 * Given an NSData produced by AddCommitUUIDAndDataToCombinedCommitData,
 * extracts the UUID : NSData pairs within it and adds them to dest
 */
void ParseCombinedCommitDataInToUUIDToItemDataDictionary(NSMutableDictionary<ETUUID *, NSData *> *dest,
                                                         NSData *commitData,
                                                         BOOL replaceExisting,
                                                         NSSet<ETUUID *>  *_Nullable restrictToItemUUIDs);

/**
 * Adds a COUUID : NSData pair to combinedCommitData
 */
void AddCommitUUIDAndDataToCombinedCommitData(NSMutableData *combinedCommitData,
                                              ETUUID *uuidToAdd,
                                              NSData *dataToAdd);

NS_ASSUME_NONNULL_END
