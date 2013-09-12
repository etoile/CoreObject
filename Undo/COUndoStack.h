#import <Foundation/Foundation.h>

@class COUndoStackStore, COEditingContext, COCommand;

@interface COUndoStack : NSObject
{
    COUndoStackStore *_store;
    NSString *_name;
}

@property (strong, readonly, nonatomic) COUndoStackStore *store;
@property (strong, readonly, nonatomic) NSString *name;

@property (weak, readonly, nonatomic) NSArray *undoNodes;
@property (weak, readonly, nonatomic) NSArray *redoNodes;

- (void) clear;

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext;
- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext;

- (void) undoWithEditingContext: (COEditingContext *)aContext;
- (void) redoWithEditingContext: (COEditingContext *)aContext;

// Private

- (void) recordCommandInverse: (COCommand *)aCommand;

@end
