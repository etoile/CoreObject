#import <Foundation/Foundation.h>

@class CORevisionID;
@class COSQLiteStore;

@interface COLeastCommonAncestor : NSObject

+ (CORevisionID *)commonAncestorForCommit: (CORevisionID *)commitA
                                andCommit: (CORevisionID *)commitB
                                    store: (COSQLiteStore *)aStore;

+ (BOOL)        isRevision: (CORevisionID *)commitA
 equalToOrParentOfRevision: (CORevisionID *)commitB
                     store: (COSQLiteStore *)aStore;

@end
