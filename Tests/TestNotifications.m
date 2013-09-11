#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestNotifications : EditingContextTestCase <UKTest>
{

}
@end

@implementation TestNotifications

- (id) init
{
    SUPERINIT;
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (void)testNotificationOnUndo
{
    COUndoStack *stack = [[COUndoStackStore defaultStore] stackForName: @"test"];
    [stack clear];
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot rootObject] setLabel: @"hello"];
    [ctx commit];
    
    [[persistentRoot rootObject] setLabel: @"world"];
    [ctx commitWithUndoStack: stack];
    
    __block int timesNotified = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName: COPersistentRootDidChangeNotification
                                                                    object: persistentRoot
                                                                     queue: nil
                                                                usingBlock: ^(NSNotification *notif) {
                                                                    UKObjectsSame(persistentRoot, [notif object]);
                                                                    timesNotified++;
                                                                }];
    
    [stack undoWithEditingContext: ctx];
    
    [[NSNotificationCenter defaultCenter] removeObserver: observer];
    
    UKIntsEqual(1, timesNotified);
}

@end
