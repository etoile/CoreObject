#import <Foundation/Foundation.h>

@class COUndoStackStore;

@interface COUndoStack : NSObject
{
    COUndoStackStore *_store;
    NSString *_name;
}

@property (readonly, nonatomic) COUndoStackStore *store;
@property (readonly, nonatomic) NSString *name;

@property (readonly, nonatomic) NSArray *undoNodes;
@property (readonly, nonatomic) NSArray *redoNodes;

/** @taskunit Framework Private */

- (id) initWithStore: (COUndoStackStore *)aStore name: (NSString *)aName;

@end
