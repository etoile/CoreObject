/**
	Copyright (C) 2012 Eric Wasylishen

	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COArrayDiff.h>
#import <CoreObject/COType.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/CODiffManager.h>

@class ETUUID;
@class COMutableItem;
@class COItemGraph;
@class COItemGraphEdit;
@class COItemGraphConflict;
@class COItemGraphDiff;
@class COSetDiff, COArrayDiff;

@class CODiffDictionary;

@interface COItemGraphConflict : NSObject // not publically copyable.
{
	@public
	COItemGraphDiff *__weak parentDiff; /* weak reference */
	NSMutableDictionary *editsForSourceIdentifier; /* id => NSMutableSet of COSubtreeEdit*/
}

@property (nonatomic, readonly, weak) COItemGraphDiff *parentDiff;

@property (nonatomic, readonly) NSSet *sourceIdentifiers;

/**
 * @returns a set of COCommand objects owned by the parent
 * diff. the caller could for example, modify them, 
 * or remove some from the parent diff
 */
- (NSSet *) editsForSourceIdentifier: (id)anIdentifier;

@property (nonatomic, readonly) NSSet *allEdits;

@property (nonatomic, readonly, getter=isNonconflicting) BOOL nonconflicting;

// private

- (void) removeEdit: (COItemGraphEdit *)anEdit;
- (void) addEdit: (COItemGraphEdit *)anEdit;

@end




/**
 * Concerns for COSubtreeDiff:
 * - conflicts arise when the same subtree is inserted in multiple places.
 * - note that a _COSubtree_ cannot exist in an inconsistent state.
 */
@interface COItemGraphDiff : NSObject <NSCopying, CODiffArraysDelegate, CODiffAlgorithm>
{
	ETUUID *oldRoot;
	ETUUID *newRoot;
	CODiffDictionary *diffDict;
	
	// right now, the conflicts are purely derived from the set of edits.
	// it could be conceivably useful to be able to insert conflicts
	// that weren't auto-detected by COSubtreeDiff from looking at the edits, 
	// but that is not currently supported.
	
	NSMutableSet *embeddedItemInsertionConflicts; // insert item uuid X at two different places
	NSMutableSet *equalEditConflicts; // e.g. set [4:2] to ("h", "i") and [4:2] to ("h", "i")
	NSMutableSet *sequenceEditConflicts; // e.g. set [4:5] and [4:3]. doesn't include equal sequence edit conflicts
	NSMutableSet *editTypeConflicts; // e.g. set-value and delete-attribute
	NSMutableSet *valueConflicts; // e.g. set attr to "x" and set attr to "y"
}

+ (COItemGraphDiff *) diffItemTree: (id <COItemGraph>)a
                     withItemTree: (id <COItemGraph>)b
                 sourceIdentifier: (id)aSource;

+ (instancetype) diffItemUUIDs: (NSArray *)uuids
					 fromGraph: (id <COItemGraph>)a
					   toGraph: (id <COItemGraph>)b
			  sourceIdentifier: (id)aSource;

/**
 * Applies the diff to the destination item graph, and returns whether the
 * item graph was changed.
 */
- (BOOL) applyTo: (id<COItemGraph>)dest;
/**
 * Returns whether the diff contains any edits.
 */
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

- (COItemGraph *) itemTreeWithDiffAppliedToItemGraph: (id<COItemGraph>)aSubtree;

- (COItemGraphDiff *)itemTreeDiffByMergingWithDiff: (COItemGraphDiff *)other;

@property (nonatomic, readonly) BOOL hasConflicts;

#pragma mark access (sub-objects may be mutated by caller)

@property (nonatomic, readonly) NSSet *allEdits;
/**
 * FIXME: Should this return "equal edit" conflicts?
 */
@property (nonatomic, readonly) NSSet *conflicts;

@property (nonatomic, readonly) NSSet *embeddedItemInsertionConflicts; // insert item uuid X at two different places
@property (nonatomic, readonly) NSSet *equalEditConflicts; // e.g. set [4:2] to ("h", "i") and [4:2] to ("h", "i")
@property (nonatomic, readonly) NSSet *sequenceEditConflicts; // e.g. set [4:5] and [4:3]. doesn't include equal sequence edit conflicts
@property (nonatomic, readonly) NSSet *editTypeConflicts; // e.g. delete + set
@property (nonatomic, readonly) NSSet *valueConflicts; // e.g. set attr to 'x' + set attr to 'y'

#pragma mark access

@property (nonatomic, readonly) NSSet *modifiedItemUUIDs;

- (NSSet *) modifiedAttributesForUUID: (ETUUID *)aUUID;
- (NSSet *) editsForUUID: (ETUUID *)aUUID;
- (NSSet *) editsForUUID: (ETUUID *)aUUID attribute: (NSString *)aString;

#pragma mark mutation

/**
 * removes conflict (by extension, all the conflicting changes)... 
 * caller should subsequently insert or update edits to reflect the
 * resolution of the conflict.
 */
- (void) removeConflict: (COItemGraphConflict *)aConflict;
- (void) addEdit: (COItemGraphEdit *)anEdit;
- (void) removeEdit: (COItemGraphEdit *)anEdit;

- (void) resolveConflictsFavoringSourceIdentifier: (NSString*)anIdentifier;

@end

