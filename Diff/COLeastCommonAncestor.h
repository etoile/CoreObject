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

@end
