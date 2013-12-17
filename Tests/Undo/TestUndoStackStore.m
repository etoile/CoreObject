/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

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

- (void) testPopByUUID
{
    [_store pushAction: D(@"d440baa2-6115-4776-bbca-700d534a7d57", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"61efa31f-84b0-4d40-8ef1-f5ae78e2fe12", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"5d005d44-7633-468f-b5ee-1016bbdab303", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
    [_store pushAction: D(@"00cea0f3-2294-4bb0-b448-729bc60668a3", kCOCommandUUID) stack: kCOUndoStack forName: @"stack1"];
	
	[_store popActionWithUUID: [ETUUID UUIDWithString: @"61efa31f-84b0-4d40-8ef1-f5ae78e2fe12"] stack: kCOUndoStack forName: @"stack1"];
	
	UKObjectsEqual(A(D(@"d440baa2-6115-4776-bbca-700d534a7d57", kCOCommandUUID),
					 D(@"5d005d44-7633-468f-b5ee-1016bbdab303", kCOCommandUUID),
					 D(@"00cea0f3-2294-4bb0-b448-729bc60668a3", kCOCommandUUID)), [_store stackContents: kCOUndoStack forName: @"stack1"]);
}

@end
