#import <Foundation/Foundation.h>

@class COUndoStackStore, COEditingContext;

@interface COUndoStack : NSObject
{
    COUndoStackStore *_store;
    NSString *_name;
}

@property (readonly, nonatomic) COUndoStackStore *store;
@property (readonly, nonatomic) NSString *name;

@property (readonly, nonatomic) NSArray *undoNodes;
@property (readonly, nonatomic) NSArray *redoNodes;

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext;
- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext;

- (void) undoWithEditingContext: (COEditingContext *)aContext;
- (void) redoWithEditingContext: (COEditingContext *)aContext;

@end
