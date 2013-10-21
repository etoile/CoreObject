#import <Foundation/Foundation.h>

@class COSQLiteStore, COStoreTransaction;

@protocol COStoreAction <NSObject>

@property (nonatomic, readonly, strong) ETUUID *persistentRoot;

- (BOOL) execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction;

@end
