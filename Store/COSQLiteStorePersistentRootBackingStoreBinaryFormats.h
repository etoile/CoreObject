#import <Foundation/Foundation.h>

@class ETUUID;

/**
 * Given an NSData produced by AddCommitUUIDAndDataToCombinedCommitData,
 * extracts the UUID : NSData pairs within it and adds them to dest
 */
void ParseCombinedCommitDataInToUUIDToItemDataDictionary(NSMutableDictionary *dest, NSData *commitData, BOOL replaceExisting, NSSet *restrictToItemUUIDs);

/**
 * Adds a COUUID : NSData pair to combinedCommitData
 */
void AddCommitUUIDAndDataToCombinedCommitData(NSMutableData *combinedCommitData, ETUUID *uuidToAdd, NSData *dataToAdd);