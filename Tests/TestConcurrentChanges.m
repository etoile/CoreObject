#import "TestCommon.h"
#import <CoreObject/COObject.h>
#import <UnitKit/UnitKit.h>

@interface TestConcurrentChanges : TestCommon <UKTest>
@end

@implementation TestConcurrentChanges

- (void)testDistributedNotification
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
 
    [ctx commit];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COObject *rootObj = [ctx2persistentRoot rootObject];
        
        [rootObj setValue: @"hello" forProperty: @"label"];
        
        //NSLog(@"Committing change to %@", [persistentRoot persistentRootUUID]);
        [ctx2 commit];
    }

    // Wait a bit for a distributed notification to arrive to ctx
    
    //NSLog(@"Starting runloop");
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    
    //NSLog(@"Runloop finished");

    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: @"label"]);
}
@end
