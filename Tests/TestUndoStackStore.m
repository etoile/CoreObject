#import "TestCommon.h"

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
    [uss release];

    _store = [[COUndoStackStore alloc] init];
    return self;
}

- (void) dealloc
{
    [_store release];
    [super dealloc];
}

- (void) testBasic
{
//    UKObjectsEqual([NSSet set], [_store stackNames]);
    
    [_store pushAction: D(@"test-1", @"type") stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"test-a", @"type") stack: kCOUndoStack forName: @"stackA"];
    [_store pushAction: D(@"test-2", @"type") stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"test-b", @"type") stack: kCOUndoStack forName: @"stackA"];
    
//    UKObjectsEqual(S(@"stack1", @"stackA"), [_store stackNames]);
    UKObjectsEqual(A(D(@"test-1", @"type"), D(@"test-2", @"type")), [_store stackContents: kCOUndoStack forName: @"stack1"]);
    UKObjectsEqual(A(D(@"test-a", @"type"), D(@"test-b", @"type")), [_store stackContents: kCOUndoStack forName: @"stackA"]);
    UKObjectsEqual([NSArray array], [_store stackContents: kCORedoStack forName: @"stack1"]);
    UKObjectsEqual([NSArray array], [_store stackContents: kCORedoStack forName: @"stackA"]);
 
    [_store popStack: kCOUndoStack forName: @"stackA"];

    UKObjectsEqual(A(D(@"test-1", @"type"), D(@"test-2", @"type")), [_store stackContents: kCOUndoStack forName: @"stack1"]);
    UKObjectsEqual(A(D(@"test-a", @"type")), [_store stackContents: kCOUndoStack forName: @"stackA"]);

    [_store pushAction: D(@"test-b", @"type") stack: kCORedoStack forName:@"stackA"];
    
    UKObjectsEqual(A(D(@"test-b", @"type")), [_store stackContents: kCORedoStack forName: @"stackA"]);
}

@end
