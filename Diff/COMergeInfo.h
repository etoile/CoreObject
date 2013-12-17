/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class COItemGraphDiff;

/**
 * NOTE: This is an unstable API which could change in the future when the
 * diff/merge support is finished
 */
@interface COMergeInfo : NSObject

@property (readwrite, nonatomic, strong) CORevision *baseRevision;
@property (readwrite, nonatomic, strong) CORevision *mergeSourceRevision;
@property (readwrite, nonatomic, strong) CORevision *mergeDestinationRevision;

@property (readwrite, nonatomic, strong) COItemGraphDiff *diff;

@end
