/*
    Copyright (C) 2012 Eric Wasylishen
 
    Date:  October 2012
    License:  MIT  (see COPYING)
 */

#import "EWUndoManager.h"

@implementation EWUndoManager

- (BOOL)canUndo
{
    return [self.delegate canUndo];
}

- (BOOL)canRedo
{
    return [self.delegate canRedo];
}

- (NSString *)undoMenuItemTitle
{
    return [self.delegate undoMenuItemTitle];
}

- (NSString *)redoMenuItemTitle
{
    return [self.delegate redoMenuItemTitle];
}

- (NSString *)undoMenuTitleForUndoActionName: (NSString *)action
{
    return nil;
}

- (NSString *)redoMenuTitleForUndoActionName: (NSString *)action
{
    return nil;
}

- (void)undo
{
    [self.delegate undo];
}

- (void)redo
{
    [self.delegate redo];
}

- (void)forwardInvocation: (NSInvocation *)invocation
{
}

- (id)prepareWithInvocationTarget: (id)target
{
    return self;
}

- (void)registerUndoWithTarget: (id)target selector: (SEL)aSelector object: (id)anObject
{
}

- (void)setActionName: (NSString *)actionName
{
}

@end
