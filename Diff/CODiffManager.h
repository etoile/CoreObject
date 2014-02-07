/**
	Copyright (C) 2014 Eric Wasylishen

	Date:  January 2014
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COItemGraph.h>
#import <EtoileFoundation/EtoileFoundation.h>

@protocol CODiffAlgorithm <NSObject>

+ (instancetype) diffItemUUIDs: (NSArray *)uuids
					 fromGraph: (id <COItemGraph>)a
					   toGraph: (id <COItemGraph>)b
			  sourceIdentifier: (id)aSource;

- (id<CODiffAlgorithm>) itemTreeDiffByMergingWithDiff: (id<CODiffAlgorithm>)aDiff;

/**
 * Returns ETUUID : COItem dictionary
 */
- (NSDictionary *) addedOrUpdatedItemsForApplyingTo: (id<COItemGraph>)dest;

- (BOOL) hasConflicts;
- (void) resolveConflictsFavoringSourceIdentifier: (id)aSource;

@end

/**
 * High-level diff class that partitions an item graph based on the diff algorithm
 * requested in each item's entity description.
 *
 * Feeds those partitions of the item graph to the relevant diff classes.
 *
 * The only use case currently is COAttributedString and its sub-components
 * (COAttributedStringChunk, COAttributedStringAttribute), which use 
 * COAttributedStringDiff. Everything else uses COItemGraphDiff.
 */
@interface CODiffManager : NSObject
{
	/**
	 * e.g. { @"COItemGraphDiff" : <COItemGraphDiff>,
	 *        @"COAttributedStringDiff" : <COAttributedStringDiff> }
	 */
	NSMutableDictionary *subDiffsByAlgorithmName;
}

+ (CODiffManager *) diffItemGraph: (id <COItemGraph>)a
					withItemGraph: (id <COItemGraph>)b
	   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository
				 sourceIdentifier: (id)aSource;

- (CODiffManager *) diffByMergingWithDiff: (CODiffManager *)otherDiff;

- (void) applyTo: (id<COItemGraph>)dest;

- (BOOL) hasConflicts;
- (void) resolveConflictsFavoringSourceIdentifier: (id)aSource;

@end
