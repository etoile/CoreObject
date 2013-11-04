#import "COSQLiteStore+Debugging.h"
#import "COSQLiteStore+Private.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "CORevisionInfo.h"

@implementation COSQLiteStore (Debugging)

- (NSString *) dotStringForRevisionUUID: (ETUUID *)aUUID
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-.*"
										 withString: @""
											options: NSRegularExpressionSearch
											  range: NSMakeRange(0, [str length])];
	
	return [@"r" stringByAppendingString: str];
}

- (void) writeDotNodeForRevisionInfo: (CORevisionInfo *)revInfo toString: (NSMutableString *)dest
{
	if (revInfo.mergeParentRevisionUUID != nil)
	{
		[dest appendFormat: @"\t%@ -> %@;\n", [self dotStringForRevisionUUID: revInfo.mergeParentRevisionUUID], [self dotStringForRevisionUUID: revInfo.revisionUUID]];
		[dest appendFormat: @"\t%@ -> %@;\n", [self dotStringForRevisionUUID: revInfo.parentRevisionUUID], [self dotStringForRevisionUUID: revInfo.revisionUUID]];
	}
	else if (revInfo.parentRevisionUUID != nil)
	{
		[dest appendFormat: @"\t%@ -> %@;\n", [self dotStringForRevisionUUID: revInfo.parentRevisionUUID], [self dotStringForRevisionUUID: revInfo.revisionUUID]];
	}
	else
	{
		[dest appendFormat: @"\t%@;\n", [self dotStringForRevisionUUID: revInfo.revisionUUID]];
	}
}

- (NSString *) dotGraphForPersistentRootUUID: (ETUUID *)aPersistentRoot
{
	NSMutableString *result = [NSMutableString string];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot
																				createIfNotPresent: YES];
		
		[result appendString: @"digraph G {\n"];
		
		NSIndexSet *revidsUsed = [backing revidsUsedRange];
		for (NSUInteger i = [revidsUsed firstIndex]; i != NSNotFound; i = [revidsUsed indexGreaterThanIndex: i])
		{
			ETUUID *revUUID = [backing revisionUUIDForRevid: i];
			if (revUUID != nil)
			{
				CORevisionInfo *revInfo = [backing revisionInfoForRevisionUUID: revUUID];
				[self writeDotNodeForRevisionInfo: revInfo toString: result];
			}
		}
		
		[result appendString: @"}\n"];

    });
    
    return result;
}

- (void) showGraphForPersistentRootUUID: (ETUUID *)aUUID
{
	NSString *basePath = [NSTemporaryDirectory() stringByAppendingPathComponent: [aUUID stringValue]];
	NSString *dotGraphPath = [basePath stringByAppendingPathExtension: @"gv"];
	NSString *psPath = [basePath stringByAppendingPathExtension: @"ps"];
	[[self dotGraphForPersistentRootUUID: aUUID] writeToFile: dotGraphPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	
	system([[NSString stringWithFormat: @"dot -Tps %@ -o %@ && open %@", dotGraphPath, psPath, psPath] UTF8String]);
}

@end
