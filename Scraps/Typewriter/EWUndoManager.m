#import "EWUndoManager.h"

@implementation EWUndoManager

- (void) setDelegate: (id<EWUndoManagerDelegate>)delegate
{
    delegate_ = delegate;
}


- (BOOL) canUndo
{
	return [delegate_ canUndo];
}

- (BOOL) canRedo
{
	return [delegate_ canRedo];
}

- (NSString *) undoMenuItemTitle
{
	return [delegate_ undoMenuItemTitle];
}
- (NSString *) redoMenuItemTitle
{
	return [delegate_ redoMenuItemTitle];
}

- (NSString *)undoMenuTitleForUndoActionName: (NSString *)action
{
	return nil;
}

- (NSString *)redoMenuTitleForUndoActionName: (NSString *)action
{
	return nil;
}

- (void) undo
{
    [delegate_ undo];
}

- (void) redo
{
    [delegate_ redo];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
}

- (id)prepareWithInvocationTarget:(id) target
{
    return self;
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
}

- (void)setActionName:(NSString*) actionName
{    
}

@end
