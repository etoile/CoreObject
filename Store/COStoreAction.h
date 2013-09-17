#import <Foundation/Foundation.h>

@class COSQLiteStore;

@protocol COStoreAction <NSObject>

- (BOOL) execute: (COSQLiteStore *)store;

@end
