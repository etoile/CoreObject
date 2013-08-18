#import "COEditingContext+Undo.h"
#import "COUndoStackStore.h"
#import "COEdit.h"

@implementation COEditingContext (Undo)

- (COEdit *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_undoStackStore peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COEdit *edit = [COEdit editWithPlist: plist];
    return edit;
}

- (BOOL) canApplyEdit: (COEdit*)anEdit
{
    if (anEdit == nil)
    {
        return NO;
    }
    
    return [anEdit canApplyToContext: self];
}

// Public API

- (BOOL) canUndoForStackNamed: (NSString *)aName
{
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    COEdit *inverse = [edit inverse];
    return [self canApplyEdit: inverse];
}

- (BOOL) canRedoForStackNamed: (NSString *)aName
{
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    COEdit *inverse = [edit inverse];
    return [self canApplyEdit: inverse];
}

- (BOOL) undoForStackNamed: (NSString *)aName
{
    [_undoStackStore beginTransaction];
    
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    if (![self canApplyEdit: edit])
    {
        [_undoStackStore commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo stack, push the inverse onto the redo stack.
    
    [_undoStackStore popStack: kCOUndoStack forName: aName];
    
    COEdit *inverse = [edit inverse];
    [inverse applyToContext: self];
    
    // N.B. This must not automatically push a revision
    [self commit];
    
    [_undoStackStore pushAction: [inverse plist] stack: kCORedoStack forName: aName];

    return [_undoStackStore commitTransaction];
}

- (BOOL) redoForStackNamed: (NSString *)aName
{
    // Same as above but swap undo and redo
}

- (BOOL) commitWithStackNamed: (NSString *)aName
{
    // Version of commit that automatically pushes a COEditGroup of the edits made
}

@end
