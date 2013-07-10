#import <Foundation/Foundation.h>

#import "COArrayDiff.h"
#import "COType.h"
#import "COItemGraph.h"

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
	COItemGraphDiff *parentDiff; /* weak reference */
	NSMutableDictionary *editsForSourceIdentifier; /* id => NSMutableSet of COSubtreeEdit*/
}

- (COItemGraphDiff *) parentDiff;

- (NSSet *) sourceIdentifiers;

/**
 * @returns a set of COEdit objects owned by the parent
 * diff. the caller could for example, modify them, 
 * or remove some from the parent diff
 */
- (NSSet *) editsForSourceIdentifier: (id)anIdentifier;

- (NSSet *) allEdits;

- (BOOL) isNonconflicting;

// private

- (void) removeEdit: (COItemGraphEdit *)anEdit;
- (void) addEdit: (COItemGraphEdit *)anEdit;

@end




/**
 * Concerns for COSubtreeDiff:
 * - conflicts arise when the same subtree is inserted in multiple places.
 * - note that a _COSubtree_ cannot exist in an inconsistent state.
 */
@interface COItemGraphDiff : NSObject <NSCopying, CODiffArraysDelegate>
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

- (COItemGraph *) itemTreeWithDiffAppliedToItemTree: (COItemGraph *)aSubtree;

- (COItemGraphDiff *)itemTreeDiffByMergingWithDiff: (COItemGraphDiff *)other;

- (BOOL) hasConflicts;

#pragma mark access (sub-objects may be mutated by caller)

- (NSSet *)allEdits;
/**
 * FIXME: Should this return "equal edit" conflicts?
 */
- (NSSet *)conflicts;

- (NSSet *) embeddedItemInsertionConflicts; // insert item uuid X at two different places
- (NSSet *) equalEditConflicts; // e.g. set [4:2] to ("h", "i") and [4:2] to ("h", "i")
- (NSSet *) sequenceEditConflicts; // e.g. set [4:5] and [4:3]. doesn't include equal sequence edit conflicts
- (NSSet *) editTypeConflicts; // e.g. delete + set
- (NSSet *) valueConflicts; // e.g. set attr to 'x' + set attr to 'y'

#pragma mark access

- (NSSet *)modifiedItemUUIDs;

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

@end

