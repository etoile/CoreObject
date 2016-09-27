/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreSetPersistentRootMetadata.h"
#import "COSQLiteStore+Private.h"
#import "COJSONSerialization.h"

@implementation COStoreSetPersistentRootMetadata

@synthesize persistentRoot, metadata;

- (NSData *)writeMetadata: (NSDictionary *)meta
{
    NSData *data = nil;
    if (meta != nil)
    {
        NSError *error = nil;

        data = CODataWithJSONObject(meta, &error);
        if (data == nil)
        {
            NSLog(@"Error serializing metadata %@ - %@", metadata, error);
        }
    }
    return data;
}

- (BOOL)execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [store.database executeUpdate: @"UPDATE persistentroots SET metadata = ? WHERE uuid = ?",
                                          [self writeMetadata: metadata],
                                          [persistentRoot dataValue]];
}

@end
