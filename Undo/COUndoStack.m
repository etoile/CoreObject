#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoStackStore.h"
#import "COUndoStack.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCommand.h"

NSString * const COUndoStackDidChangeNotification = @"COUndoStackDidChangeNotification";
NSString * const kCOUndoStackName = @"COUndoStackName";

@interface COUndoStack ()

@property (strong, readwrite, nonatomic) COUndoStackStore *store;
@property (strong, readwrite, nonatomic) NSString *name;

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
    COCommand *edit = [self peekEditFromStack: kCOUndoStack forName: _name];
    return [self canApplyEdit: edit toContext: aContext];
}

- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext
{
    COCommand *edit = [self peekEditFromStack: kCORedoStack forName: _name];
    return [self canApplyEdit: edit toContext: aContext];
}

- (void) undoWithEditingContext: (COEditingContext *)aContext
{
    [self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: _name toContext: aContext];
}
- (void) redoWithEditingContext: (COEditingContext *)aContext
{
    [self popAndApplyFromStack: kCORedoStack pushToStack: kCOUndoStack name: _name toContext: aContext];
}

- (void) clear
{
    [_store clearStack: kCOUndoStack forName: _name];
    [_store clearStack: kCORedoStack forName: _name];
}


- (COCommand *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_store peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COCommand *edit = [COCommand commandWithPlist: plist];
    return edit;
}

- (BOOL) canApplyEdit: (COCommand*)anEdit toContext: (COEditingContext *)aContext
{
    if (anEdit == nil)
    {
        return NO;
    }
    
    return [anEdit canApplyToContext: aContext];
}

- (BOOL) popAndApplyFromStack: (NSString *)popStack
                  pushToStack: (NSString*)pushStack
                         name: (NSString *)aName
                    toContext: (COEditingContext *)aContext
{
    [_store beginTransaction];
    
    NSString *actualStackName = [_store peekStackName: popStack forName: aName];
    COCommand *edit = [self peekEditFromStack: popStack forName: aName];
    if (![self canApplyEdit: edit toContext: aContext])
    {
        // DEBUG: Break here
        edit = [self peekEditFromStack: popStack forName: aName];
        [self canApplyEdit: edit toContext: aContext];
        
        [_store commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo stack
    [_store popStack: popStack forName: aName];
    
    // Apply the edit
    [edit applyToContext: aContext];
    
    // N.B. This must not automatically push a revision
    aContext.isRecordingUndo = NO;
    [aContext commit];
    aContext.isRecordingUndo = YES;
    
    // Push the inverse onto the redo stack
    COCommand *inverse = [edit inverse];
    
    [_store pushAction: [inverse plist] stack: pushStack forName: actualStackName];
    
    return [_store commitTransaction];
}

- (void) recordCommandInverse: (COCommand *)aCommand
{
    id plist = [aCommand plist];
    //NSLog(@"Undo event: %@", plist);
    
    // N.B. The kCOUndoStack contains COCommands that are the inverse of
    // what the user did. So if the user creates a persistent root,
    // we push an edit to kCOUndoStack that deletes that persistent root.
    // => to perform an undo, pop from the kCOUndoStack and apply the edit.
    
    [_store pushAction: plist stack: kCOUndoStack forName: _name];
    
    [self postNotificationsForStackName: _name];
}

- (void) postNotificationsForStackName: (NSString *)aStack
{
    NSDictionary *userInfo = @{kCOUndoStackName : aStack};
    
    [[NSNotificationCenter defaultCenter] postNotificationName: COUndoStackDidChangeNotification
                                                        object: self
                                                      userInfo: userInfo];
    
    //    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
    //                                                                   object: [[self UUID] stringValue]
    //                                                                 userInfo: userInfo
    //                                                       deliverImmediately: NO];
}

@end
