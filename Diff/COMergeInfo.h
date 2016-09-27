/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class CODiffManager;

/**
 * NOTE: This is an unstable API which could change in the future when the
 * diff/merge support is finished
 */
@interface COMergeInfo : NSObject

@property (nonatomic, readwrite, strong) CORevision *baseRevision;
@property (nonatomic, readwrite, strong) CORevision *mergeSourceRevision;
@property (nonatomic, readwrite, strong) CORevision *mergeDestinationRevision;
@property (nonatomic, readwrite, strong) CODiffManager *diff;

@end
