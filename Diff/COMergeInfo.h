#import <Foundation/Foundation.h>

@class CORevisionID;
@class COItemGraphDiff;

@interface COMergeInfo : NSObject

@property (readwrite, nonatomic, retain) CORevision *baseRevision;
@property (readwrite, nonatomic, retain) CORevision *mergeSourceRevision;
@property (readwrite, nonatomic, retain) CORevision *mergeDestinationRevision;

@property (readwrite, nonatomic, retain) COItemGraphDiff *diff;

@end
