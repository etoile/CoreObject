#import "TestCommon.h"
#import "COCommand.h"

@interface TestUndoStackStore : NSObject <UKTest>
{
    COUndoStackStore *_store;
}

@end

@implementation TestUndoStackStore

- (id) init
{
    SUPERINIT;
    
    COUndoStackStore *uss = [[COUndoStackStore alloc] init];
    for (NSString *stack in A(@"stack1", @"stackA"))
    {
        [uss clearStacksForName: stack];
    }

    _store = [[COUndoStackStore alloc] init];
    return self;
}


- (void) testBasic
{
//    UKObjectsEqual([NSSet set], [_store stackNames]);
    
    [_store pushAction: D(@"test-1", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"test-a", kCOCommandUUID) stack: kCOUndoStack forName: @"stackA"];
    [_store pushAction: D(@"test-2", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"test-b", kCOCommandUUID) stack: kCOUndoStack forName: @"stackA"];
    
//    UKObjectsEqual(S(@"stack1", @"stackA"), [_store stackNames]);
    UKObjectsEqual(A(D(@"test-1", kCOCommandUUID), D(@"test-2", kCOCommandUUID)), [_store stackContents: kCOUndoStack forName: @"stack1"]);
    UKObjectsEqual(A(D(@"test-a", kCOCommandUUID), D(@"test-b", kCOCommandUUID)), [_store stackContents: kCOUndoStack forName: @"stackA"]);
    UKObjectsEqual([NSArray array], [_store stackContents: kCORedoStack forName: @"stack1"]);
    UKObjectsEqual([NSArray array], [_store stackContents: kCORedoStack forName: @"stackA"]);
 
    [_store popStack: kCOUndoStack forName: @"stackA"];

    UKObjectsEqual(A(D(@"test-1", kCOCommandUUID), D(@"test-2", kCOCommandUUID)), [_store stackContents: kCOUndoStack forName: @"stack1"]);
    UKObjectsEqual(A(D(@"test-a", kCOCommandUUID)), [_store stackContents: kCOUndoStack forName: @"stackA"]);

    [_store pushAction: D(@"test-b", kCOCommandUUID) stack: kCORedoStack forName:@"stackA"];
    
    UKObjectsEqual(A(D(@"test-b", kCOCommandUUID)), [_store stackContents: kCORedoStack forName: @"stackA"]);
}

@end
