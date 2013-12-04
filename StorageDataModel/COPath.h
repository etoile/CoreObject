#import <Foundation/Foundation.h>

@class ETUUID;

/**
 *
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
@property (strong, readonly) ETUUID *persistentRoot;
/**
 * May be nil, which indicates that the path points to whatever the current branch 
 * of persistentRoot is.
 */
@property (strong, readonly) ETUUID *branch;

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
