#import "COStoreSetBranchMetadata.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreSetBranchMetadata

@synthesize branch, persistentRoot, metadata;

- (NSData *) writeMetadata: (NSDictionary *)meta
{
    NSData *data = nil;
    if (meta != nil)
    {
        data = [NSJSONSerialization dataWithJSONObject: meta options: 0 error: NULL];
        if (data == nil)
        {
            NSLog(@"Error serializing branch metadata %@", metadata);
        }
    }
    return data;
}

- (BOOL) execute: (COSQLiteStore *)store
{
    return [[store database] executeUpdate: @"UPDATE branches SET metadata = ? WHERE uuid = ?",
            [self writeMetadata: metadata],
            [branch dataValue]];
}

@end
