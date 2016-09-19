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
/**
 * Returns whether the diff contains any edits.
 */
@property (nonatomic, getter=isEmpty, readonly) BOOL empty;

@property (nonatomic, readonly) BOOL hasConflicts;
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


/** @taskunit Accessing Subdiffs */


/**
 * Returns the diff portion corresponding to this algorithm.
 *
 * The returned diff applied to all the items whose entity description requested 
 * this algorithm with -[ETEntityDescription diffAlgorithm].
 *
 * The returned subdiff always conforms to CODiffAlgorithm.
 */
- (id)subdiffForAlgorithmName: (NSString *)aDiffAlgorithmName;
/**
 * Adds a subdiff using its class name to map it to an algorithm name.
 *
 * If a subdiff already exists for this algorithm, it is replaced.
 */
- (void)addSubdiff: (id <CODiffAlgorithm>)aSubdiff;

/**
 * Applies the diff to the destination item graph, and returns whether the
 * item graph was changed.
 */
- (BOOL) applyTo: (id<COItemGraph>)dest;
/**
 * Returns whether the diff contains any edits.
 */
@property (nonatomic, getter=isEmpty, readonly) BOOL empty;

@property (nonatomic, readonly) BOOL hasConflicts;
- (void) resolveConflictsFavoringSourceIdentifier: (id)aSource;

@end
