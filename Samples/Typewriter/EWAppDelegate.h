#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@interface EWAppDelegate : NSObject
{
    COSQLiteStore *_store;
    COEditingContext *_context;
}

- (COSQLiteStore *) store;
- (COEditingContext *) editingContext;

@end
