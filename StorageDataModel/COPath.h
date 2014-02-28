/**
    Copyright (C) 2011 Eric Wasylishen

    Date:  November 2011
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;

/**
 * @group Storage Data Model
 * @abstract 
 * COPath represents a cross-persistent root reference to the root object of a 
 * persistent root. 
 *
 * It can either point to whatever the current branch is when the COPath is 
 * dereferenced, or can point to a specific branch.
 *
 * COPath is used as a value object inside COItem.
 */
@interface COPath : NSObject <NSCopying>
{
@private
	ETUUID *_persistentRoot;
	ETUUID *_branch;
}


/** @taskunit Initialization */


/**
 * Returns a new path that implicitly points to the root object of the current 
 * branch.
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot;
/**
 * Returns a new path that implicitly points to the root object.
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
                             branch: (ETUUID*)aBranch;


/** @taskunit Reference Properties */


/**
 * The UUID of the referenced persistent root.
 *
 * Never nil.
 */
@property (nonatomic, readonly, strong) ETUUID *persistentRoot;
/**
 * The UUID of the referenced branch.
 *
 * May be nil, which indicates that the path points to whatever the current 
 * branch of persistentRoot is.
 */
@property (nonatomic, readonly, strong) ETUUID *branch;


/** @taskunit Persistent String Representation */


/**
 * Returns a new path from a string representation such as -stringValue.
 */
+ (COPath *) pathWithString: (NSString*) pathString;
/**
 * Returns a string representation of the path.
 */
- (NSString *) stringValue;

@end
