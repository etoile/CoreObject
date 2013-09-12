#import <Foundation/Foundation.h>

@class CORevisionID;
@class COItemGraphDiff;

@interface COMergeInfo : NSObject

@property (readwrite, nonatomic, strong) CORevision *baseRevision;
@property (readwrite, nonatomic, strong) CORevision *mergeSourceRevision;
@property (readwrite, nonatomic, strong) CORevision *mergeDestinationRevision;

@property (readwrite, nonatomic, strong) COItemGraphDiff *diff;

@end
