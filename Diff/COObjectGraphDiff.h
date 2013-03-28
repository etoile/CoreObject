#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COArrayDiff, COSetDiff, COEditingContext, COObject, COContainer, CORevision;

/**
 * 
 */
@interface COObjectGraphDiff : NSObject
{
	NSMutableDictionary *_editsByPropertyAndUUID; // This maps { uuid : { property_name : COObjectGraphEdit object } }
	NSMutableSet *_deletedObjectUUIDs;
	NSMutableDictionary *_insertedObjectsByUUID;
}

- (void)recordRemoveProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj;
- (void)recordSetValue: (id)value forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj;
- (void)recordModifyArray: (COArrayDiff *)diff forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj;
- (void)recordModifySet: (COSetDiff *)diff forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj;

- (void)applyToContext: (COEditingContext*)ctx;
@end


@interface COObjectGraphDiff (Factory)

+ (COObjectGraphDiff *)diffObjectsWithUUIDs: (NSArray*)objectUUIDs
								  inContext: (COEditingContext*)base 
								withContext: (COEditingContext*)other;

/**
 * Convenience method
 */
// + (COObjectGraphDiff *)diffHistoryNode: (id)n1
// 					   withHistoryNode: (id)n2;

/**
 * Convenience method
 */
+ (COObjectGraphDiff *)diffContainer: (COContainer*)group1 withContainer: (COContainer*)group2;
+ (COObjectGraphDiff *)diffRootObject: (COObject *)baseObject 
                       withRootObject: (COObject *)otherObject;

+ (COObjectGraphDiff *)selectiveUndoDiffWithRootObject: (COObject *)aRootObject 
                                        revisionToUndo: (CORevision *)revToUndo;

@end

@interface COObjectGraphDiff (Merge)

+ (COObjectGraphDiff*) mergeDiff: (COObjectGraphDiff*)diff1 withDiff: (COObjectGraphDiff*)diff2;

@end
