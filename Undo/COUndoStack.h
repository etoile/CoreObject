#import <Foundation/Foundation.h>

@class COUndoStackStore, COEditingContext, COCommand;

@interface COUndoStack : NSObject
{
    COUndoStackStore *_store;
    NSString *_name;
}

@property (readonly, nonatomic) COUndoStackStore *store;
@property (readonly, nonatomic) NSString *name;

@property (readonly, nonatomic) NSArray *undoNodes;
@property (readonly, nonatomic) NSArray *redoNodes;

- (void) clear;

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext;
- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext;

- (void) undoWithEditingContext: (COEditingContext *)aContext;
- (void) redoWithEditingContext: (COEditingContext *)aContext;

// Private

- (void) recordCommandInverse: (COCommand *)aCommand;

@end
