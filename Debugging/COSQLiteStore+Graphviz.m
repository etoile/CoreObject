/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  November 2013
	License:  MIT  (see COPYING)
 */

#import "COSQLiteStore+Graphviz.h"
#import "COSQLiteStore+Private.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "CORevisionInfo.h"
#import "COPersistentRootInfo.h"
#import "COBranchInfo.h"
#import <AppKit/AppKit.h>

@implementation COSQLiteStore (Debugging)

- (NSString *) dotNameForRevisionUUID: (ETUUID *)aUUID
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
	
	return [@"rev_" stringByAppendingString: str];
}

- (NSString *) dotNameForBranchUUID: (ETUUID *)aUUID
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
	
	return [@"branch_" stringByAppendingString: str];
}

- (NSString *) labelForMetadata: (NSDictionary *)metadata
{
	NSString *escapedMetadata = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject: metadata options: 0 error: NULL]
													  encoding: NSUTF8StringEncoding];
	// FIXME: escape escapedMetadata
	return escapedMetadata;
}

- (void) writeDotNodeForRevisionInfo: (CORevisionInfo *)revInfo toString: (NSMutableString *)dest
{
	if (revInfo.mergeParentRevisionUUID != nil)
	{
		[dest appendFormat: @" %@ -> %@ [color=orange];\n", [self dotNameForRevisionUUID: revInfo.mergeParentRevisionUUID], [self dotNameForRevisionUUID: revInfo.revisionUUID]];
		[dest appendFormat: @" %@ -> %@;\n", [self dotNameForRevisionUUID: revInfo.parentRevisionUUID], [self dotNameForRevisionUUID: revInfo.revisionUUID]];
	}
	else if (revInfo.parentRevisionUUID != nil)
	{
		[dest appendFormat: @" %@ -> %@;\n", [self dotNameForRevisionUUID: revInfo.parentRevisionUUID], [self dotNameForRevisionUUID: revInfo.revisionUUID]];
	}
	else
	{
		[dest appendFormat: @" %@;\n", [self dotNameForRevisionUUID: revInfo.revisionUUID]];
	}
	
	if (revInfo.metadata != nil)
	{
		[dest appendFormat: @" %@ -> %@_metadata [style=dotted,label=\"metadata\"];\n",
		 [self dotNameForRevisionUUID: revInfo.revisionUUID],
		 [self dotNameForRevisionUUID: revInfo.revisionUUID]];
		
		NSString *escapedMetadata = [self labelForMetadata: revInfo.metadata];
		
		[dest appendFormat: @" %@_metadata [shape=box,color=red,label=<%@>];\n",
		 [self dotNameForRevisionUUID: revInfo.revisionUUID],
		 escapedMetadata];
	}
}

- (NSString *) dotGraphForPersistentRootUUID: (ETUUID *)aPersistentRoot
{
	NSMutableString *result = [NSMutableString string];
    
	COPersistentRootInfo *info = [self persistentRootInfoForUUID: aPersistentRoot];
	
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot
																				createIfNotPresent: YES];
		
		[result appendString: @"digraph G {\n"];
		
		// Add revisions
		
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
		
		// Add branches
		
		for (ETUUID *branchUUID in info.branchUUIDs)
		{
			COBranchInfo *branchInfo = [info branchInfoForUUID:branchUUID];
			
			if ([branchInfo.headRevisionUUID isEqual: branchInfo.currentRevisionUUID])
			{
				[result appendFormat: @" %@ -> %@ [style=dotted];\n",
				 [self dotNameForBranchUUID: branchInfo.UUID],
				 [self dotNameForRevisionUUID: branchInfo.headRevisionUUID]];
			}
			else
			{
				[result appendFormat: @" %@ -> %@ [style=dotted,label=\"head\"];\n",
				 [self dotNameForBranchUUID: branchInfo.UUID],
				 [self dotNameForRevisionUUID: branchInfo.headRevisionUUID]];

				[result appendFormat: @" %@ -> %@ [style=dotted,label=\"current\"];\n",
				 [self dotNameForBranchUUID: branchInfo.UUID],
				 [self dotNameForRevisionUUID: branchInfo.currentRevisionUUID]];
			}
			
			if (branchInfo.metadata != nil)
			{
				[result appendFormat: @" %@ -> %@_metadata [style=dotted,label=\"metadata\"];\n",
				 [self dotNameForBranchUUID: branchInfo.UUID],
				 [self dotNameForBranchUUID: branchInfo.UUID]];

				NSString *escapedMetadata = [self labelForMetadata: branchInfo.metadata];
				// FIXME: escape escapedMetadata
				
				[result appendFormat: @" %@_metadata [shape=box,color=red,label=<%@>];\n",
				 [self dotNameForBranchUUID: branchInfo.UUID],
				 escapedMetadata];
			}
			
			[result appendFormat: @" %@ [shape=box];\n",
			 [self dotNameForBranchUUID: branchInfo.UUID]];
		}
		
		[result appendString: @"}\n"];

    });
    
    return result;
}

- (void) showGraphForPersistentRootUUID: (ETUUID *)aUUID
{
	NSString *basePath = [NSString stringWithFormat: @"%@-%d",
						  [NSTemporaryDirectory() stringByAppendingPathComponent: [aUUID stringValue]],
						  rand()];
	
	NSString *dotGraphPath = [basePath stringByAppendingPathExtension: @"gv"];
	
	[[self dotGraphForPersistentRootUUID: aUUID] writeToFile: dotGraphPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	
	COViewDOTGraphFile(dotGraphPath);
}

void COViewDOTGraphFile(NSString *dotFilePath)
{
	NSString *pdfPath = [dotFilePath stringByAppendingPathExtension: @"pdf"];

	for (NSString *executablePath in @[@"/usr/bin/dot", @"/usr/local/bin/dot"])
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath: executablePath])
		{
			continue;
		}

		// NOTE: Using NSTask rather than system() breaks 'po [objectGraphContext showGraph]' in LLDB on 10.7 
		system([[NSString stringWithFormat: @"%@ -Tpdf '%@' -o '%@'", executablePath, dotFilePath, pdfPath] UTF8String]);
		[[NSWorkspace sharedWorkspace] openFile: pdfPath];
		break;
	}
}

@end
