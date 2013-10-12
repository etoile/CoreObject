#import "COStoreSetCurrentRevision.h"
#import "COSQLiteStore+Private.h"
#import "FMDatabaseAdditions.h"

@implementation COStoreSetCurrentRevision

@synthesize branch, persistentRoot, currentRevision, headRevision;

- (BOOL) execute: (COSQLiteStore *)store
{
    BOOL ok = [[store database] executeUpdate: @"UPDATE branches SET current_revid = ? WHERE uuid = ?",
            [currentRevision dataValue], [branch dataValue]];
	
	if (headRevision != nil)
	{
		ok = [[store database] executeUpdate: @"UPDATE branches SET head_revid = ? WHERE uuid = ?",
			  [headRevision dataValue], [branch dataValue]];
	}
	
	return ok;
}

@end
