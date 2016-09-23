/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStorePersistentRootBackingStoreBinaryFormats.h"
#import <EtoileFoundation/ETUUID.h>

void ParseCombinedCommitDataInToUUIDToItemDataDictionary(NSMutableDictionary *dest, NSData *commitData, BOOL replaceExisting, NSSet *restrictToItemUUIDs)
{
    // format:
    //
    // |-----------------------|---------------------------------------------------| |---..
    // | uint_32 little-endian | item data (first byte is '#', then 16-byte  UUID) | | next length..
    // |-----------------------|---------------------------------------------------| |---..
    //    ^- length in bytes of item data
    
    const unsigned char *bytes = commitData.bytes;
    const NSUInteger len = commitData.length;
    NSUInteger offset = 0;
    
    while (offset < len)
    {
        uint32_t length;
        memcpy(&length, bytes + offset, 4);
        length = NSSwapLittleIntToHost(length);
        offset += 4;
        
		assert('#' == bytes[offset]);
		ETUUID *uuid = [[ETUUID alloc] initWithUUID: bytes + offset + 1];
		
        if ((replaceExisting
             || nil == dest[uuid])
            && (nil == restrictToItemUUIDs
                || [restrictToItemUUIDs containsObject: uuid]))
        {

            NSData *data = [commitData subdataWithRange: NSMakeRange(offset, length)];
            dest[uuid] = data;
        }
        offset += length;
    }
}

void AddCommitUUIDAndDataToCombinedCommitData(NSMutableData *combinedCommitData, ETUUID *uuidToAdd, NSData *dataToAdd)
{
    const NSUInteger len = dataToAdd.length;
    if (len > UINT32_MAX)
    {
        [NSException raise: NSInvalidArgumentException format: @"Can't write item data larger than 2^32-1 bytes"];
    }
    uint32_t swappedInt = NSSwapHostIntToLittle((uint32_t)len);
    
    [combinedCommitData appendBytes: &swappedInt
                             length: 4];
    
    [combinedCommitData appendData: dataToAdd];

	assert('#' == ((const unsigned char *)[dataToAdd bytes])[0]);
	assert(0 == memcmp([uuidToAdd UUIDValue], ((const unsigned char *)[dataToAdd bytes]) + 1, 16));
}
