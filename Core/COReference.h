#import <Foundation/Foundation.h>

@class COPersistentRoot, COBranch, COObject;

/**
 * High-level counterpart to COPath. Not sure if it's necessary to be a
 * separate class but following the pattern of having separate types
 * (COObject vs COItem, COPersistentRoot vs COPersistentRootInfo etc.)
 *
 * 
 */
@interface COReference : NSObject
{
    COObject *_owningObject;
    NSString *_owningProperty;
    
}

+ (COReference *) referenceToCurrentBranchOfPersistentRoot: (COPersistentRoot *)aPersistentRoot;
+ (COReference *) referenceToBranch: (COBranch *)aBranch;
+ (COReference *) referenceToInnerObject: (COObject *)anObject;

@property (readwrite, nonatomic) BOOL isToCurrentBranch;
@property (readwrite, nonatomic, assign) COBranch *branch;
@property (readwrite, nonatomic, assign) COPersistentRoot *persistentRoot;

- (BOOL) isBroken;
- (BOOL) isInnerReference;

@end
