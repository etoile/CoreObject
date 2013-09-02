#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoStackStore.h"
#import "COUndoStack.h"
#import "COEditingContext+Undo.h"

@interface COUndoStack ()

@property (readwrite, retain, nonatomic) COUndoStackStore *store;
@property (readwrite, retain, nonatomic) NSString *name;

@end

@implementation COUndoStack

- (id) initWithStore: (COUndoStackStore *)aStore name: (NSString *)aName
{
    SUPERINIT;
    self.name = aName;
    self.store = aStore;
    return self;
}

@synthesize name = _name, store = _store;

- (NSArray *) undoNodes
{
    return [_store stackContents: kCOUndoStack forName: _name];
}

- (NSArray *) redoNodes
{
    return [_store stackContents: kCORedoStack forName: _name];
}

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext
{
    return [aContext canUndoForStackNamed: _name];
}

- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext
{
    return [aContext canRedoForStackNamed: _name];
}

- (void) undoWithEditingContext: (COEditingContext *)aContext
{
    [aContext undoForStackNamed: _name];
}
- (void) redoWithEditingContext: (COEditingContext *)aContext
{
    [aContext redoForStackNamed: _name];
}

@end
