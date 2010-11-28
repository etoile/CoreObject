#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COContainer.h"
#import "COArrayDiff.h"
#import "COSetDiff.h"


@class COObject;
@class COEditingContext;

/**
 * 
 */
@interface COObjectGraphDiff : NSObject
{
	NSMutableDictionary *_editsByPropertyAndUUID; // This maps { uuid : { property_name : COObjectGraphEdit object } }
	NSMutableArray *_deletedObjectUUIDs;
	NSMutableDictionary *_insertedObjectDataByUUID;
}

- (void)recordRemoveProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordSetValue: (id)value forProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordModifyArray: (COArrayDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordModifySet: (COSetDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj;

- (void)applyToContext: (COEditingContext*)ctx;
@end


@interface COObjectGraphDiff (Factory)

+ (COObjectGraphDiff *)diffObjectsWithUUIDs: (NSArray*)objectUUIDs
								  inContext: (COEditingContext*)base 
								withContext: (COEditingContext*)other;

/**
 * Convenience method
 */
+ (COObjectGraphDiff *)diffHistoryNode: (id)n1
					   withHistoryNode: (id)n2;

/**
 * Convenience method
 */
+ (COObjectGraphDiff *)diffContainer: (COContainer*)group1 withContainer: (COContainer*)group2;

@end

@interface COObjectGraphDiff (Merge)

+ (COObjectGraphDiff*) mergeDiff: (COObjectGraphDiff*)diff1 withDiff: (COObjectGraphDiff*)diff2;

@end
