#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoStackStore.h"
#import "COUndoStack.h"


@implementation COUndoStack

- (id) initWithStore: (COUndoStackStore *)aStore name: (NSString *)aName
{
    SUPERINIT;
    ASSIGN(_store, aStore);
    ASSIGN(_name, aName);
    return self;
}

@synthesize name, store;

- (NSArray *) undoNodes
{
    return nil;
}

- (NSArray *) redoNodes
{
    return nil;    
}


@end
