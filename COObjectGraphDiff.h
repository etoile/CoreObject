#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COArrayDiff.h"
#import "COSetDiff.h"

@class COObject;
@class COObjectContext;

/**
 * 
 */
@interface COObjectGraphDiff : NSObject
{
  NSMutableDictionary *_editsByPropertyAndUUID; // This maps { uuid : { property_name : COObjectGraphEdit object } }
}

- (void)recordRemoveProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordSetValue: (id)value forProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordModifyArray: (COArrayDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj;
- (void)recordModifySet: (COSetDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj;

- (void)applyToContext: (COObjectContext*)ctx;
@end


@interface COObjectGraphDiff (Factory)

+ (COObjectGraphDiff *)diffObjectContext: (COObjectContext*)base with: (COObjectContext*)modified;
+ (COObjectGraphDiff *)diffObject: (COObject *)base with: (COObject *)other;

@end

@interface COObjectGraphDiff (Merge)

+ (COObjectGraphDiff*) mergeDiff: (COObjectGraphDiff*)diff1 withDiff: (COObjectGraphDiff*)diff2;

@end
