#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

/**
 *
 */
@interface COPath : NSObject <NSCopying>
{
@private
	ETUUID *persistentRoot_;
	ETUUID *branch_;
	ETUUID *embeddedObject_;
}

/**
 * Returns YES if persistentRoot is set
 */
- (BOOL) isCrossPersistentRoot;

@property (readonly) ETUUID *persistentRoot;
@property (readonly) ETUUID *branch;
@property (readonly) ETUUID *embeddedObject;

/**
 * Implicitly points to the root object of the current branch
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot;

/**
 * Implicitly points to the root object
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch;

/**
 * Deprecated. COPath can only point at the root object.
 */
+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch
					embdeddedObject: (ETUUID *)anObject;

- (COPath *) pathWithNameMapping: (NSDictionary *)aMapping;

// string persistence

+ (COPath *) pathWithString: (NSString*) pathString;
- (NSString *) stringValue;

@end
