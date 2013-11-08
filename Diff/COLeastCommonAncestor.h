#import <Foundation/Foundation.h>

@class ETUUID;
@class COSQLiteStore;

@interface COLeastCommonAncestor : NSObject

+ (ETUUID *)commonAncestorForCommit: (ETUUID *)commitA
                          andCommit: (ETUUID *)commitB
					 persistentRoot: (ETUUID *)persistentRoot
                              store: (COSQLiteStore *)aStore;

+ (BOOL)        isRevision: (ETUUID *)commitA
 equalToOrParentOfRevision: (ETUUID *)commitB
			persistentRoot: (ETUUID *)persistentRoot
                     store: (COSQLiteStore *)aStore;

/**
 * As a sepecial case if [start isEqual: end] returns the empty array
 */
+ (NSArray *) revisionUUIDsFromRevisionUUIDExclusive: (ETUUID *)start
							 toRevisionUUIDInclusive: (ETUUID *)end
									  persistentRoot: (ETUUID *)persistentRoot
											   store: (COSQLiteStore *)aStore;

@end
