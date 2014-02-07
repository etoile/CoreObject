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
 * COPath represents a cross-persistent root reference to the root object of
 * a persistent root. It can either point to whatever the current branch is when
 * the COPath is dereferenced, or can point to a specific branch.
 * 
 * COPath is used as a value object inside COItem.
 */
@interface COPath : NSObject <NSCopying>
{
@private
	ETUUID *_persistentRoot;
	ETUUID *_branch;
}

/**
 * Non-nil
 */
@property (nonatomic, readonly, strong) ETUUID *persistentRoot;
/**
 * May be nil, which indicates that the path points to whatever the current branch 
 * of persistentRoot is.
 */
@property (nonatomic, readonly, strong) ETUUID *branch;

/**
 * Implicitly points to the root object of the current branch
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot;

/**
 * Implicitly points to the root object
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch;

// string persistence

+ (COPath *) pathWithString: (NSString*) pathString;
- (NSString *) stringValue;

@end
