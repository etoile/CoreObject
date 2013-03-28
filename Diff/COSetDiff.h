#import <Foundation/Foundation.h>
#import "COMergeResult.h"

@interface COSetDiff : NSObject
{
	NSArray *ops;
}

// Creating

- (id) initWithFirstSet: (NSSet *)first
              secondSet: (NSSet *)second;

- (id) initWithOperations: (NSArray *)operations;

// Examining

- (NSArray *)operations;
- (NSSet *)addedObjects;
- (NSSet *)removedObjects;

// Applying

- (void) applyTo: (NSMutableSet*)array;
- (NSSet *)setWithDiffAppliedTo: (NSSet *)array;

// Merging with another COSetDiff

- (COMergeResult *)mergeWith: (COSetDiff *)other;

@end


@interface COSetDiffOperationAdd : NSObject
{
	NSSet *addedObjects;
}
@property (nonatomic, retain, readonly) NSSet *addedObjects;
+ (COSetDiffOperationAdd*)addOperationWithAddedObjects: (NSSet*)add;
- (void) applyTo: (NSMutableSet*)set;
@end

@interface COSetDiffOperationRemove : NSObject
{
	NSSet *removedObjects;
}
@property (nonatomic, retain, readonly) NSSet *removedObjects;
+ (COSetDiffOperationRemove*)removeOperationWithRemovedObjects: (NSSet*)remove;
- (void) applyTo: (NSMutableSet*)set;
@end
