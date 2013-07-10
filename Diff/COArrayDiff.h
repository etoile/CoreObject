#import <Foundation/Foundation.h>

@protocol CODiffArraysDelegate

- (void)recordInsertionWithLocation: (NSUInteger)aLocation
					insertedObjects: (id)anArray
						   userInfo: (id)info;

- (void)recordDeletionWithRange: (NSRange)aRange
					   userInfo: (id)info;

- (void)recordModificationWithRange: (NSRange)aRange
					insertedObjects: (id)anArray
						   userInfo: (id)info;

@end

void CODiffArrays(NSArray *arrayA, NSArray *arrayB, id<CODiffArraysDelegate>delegate, id userInfo);

void COApplyEditsToArray(NSMutableArray *array, NSArray *edits);

NSArray *COArrayByApplyingEditsToArray(NSArray *array, NSArray *edits);