/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestSynchronizerCommon.h"

@interface TestSynchronizerPerformance : TestSynchronizerCommon <UKTest>
@end

@implementation TestSynchronizerPerformance

/**
 * This is a version of testConflictingAttributedStringInserts but designed for benchmarking.
 */
- (void) testAttributedStringRebasePerformance
{
    NSString *charactersToInsert = @"Hello, this is the first insertion which will be inserted character-by-character. ";
    NSString *stringToInsert = @"Another insertion. ";
    NSString *baseString = @"Test.";
    
    COAttributedString *serverStr = [[COAttributedString alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
    COAttributedStringWrapper *serverWrapper = [[COAttributedStringWrapper alloc] initWithBacking: serverStr];
    [serverWrapper replaceCharactersInRange: NSMakeRange(0, 0) withString: baseString];
    [(UnorderedGroupNoOpposite *)serverBranch.rootObject setContents: S(serverStr)];
    [serverPersistentRoot commit];
    
    [transport deliverMessagesToClient];
    
    // several commits on client
    
    COAttributedString *clientStr = [[(UnorderedGroupNoOpposite *)clientBranch.rootObject contents] anyObject];
    COAttributedStringWrapper *clientWrapper = [[COAttributedStringWrapper alloc] initWithBacking: clientStr];
    
    UKObjectsEqual(baseString, clientWrapper.string);
    
    for (NSUInteger i = 0; i < charactersToInsert.length; i++)
    {
        [clientWrapper replaceCharactersInRange: NSMakeRange(i, 0)
                                     withString: [charactersToInsert substringWithRange: NSMakeRange(i, 1)]];
        [clientPersistentRoot commit];
    }
    
    UKObjectsEqual([charactersToInsert stringByAppendingString: baseString], clientWrapper.string);
    
    // 1 commit on server
    
    [serverWrapper replaceCharactersInRange: NSMakeRange(0,0) withString: stringToInsert];
    [serverPersistentRoot commit];
    
    // deliver first client commit to server. This will be the first character of 'charactersToInsert'
    [transport deliverMessagesToServer];
    
    UKTrue(([[NSString stringWithFormat: @"%@%@%@", stringToInsert, [charactersToInsert substringToIndex: 1], baseString] isEqualToString: serverWrapper.string]
           || [[NSString stringWithFormat: @"%@%@%@", [charactersToInsert substringToIndex: 1], stringToInsert, baseString] isEqualToString: serverWrapper.string]));
    
    [transport deliverMessagesToClient];
    
    // Send confirmation to server
    [transport deliverMessagesToServer];

    // Send confirmation back to client
    [transport deliverMessagesToClient];
    
    UKTrue(([[NSString stringWithFormat: @"%@%@%@", stringToInsert, charactersToInsert, baseString] isEqualToString: serverWrapper.string]
           || [[NSString stringWithFormat: @"%@%@%@", charactersToInsert, stringToInsert, baseString] isEqualToString: serverWrapper.string]));

    UKTrue(([[NSString stringWithFormat: @"%@%@%@", stringToInsert, charactersToInsert, baseString] isEqualToString: clientWrapper.string]
           || [[NSString stringWithFormat: @"%@%@%@", charactersToInsert, stringToInsert, baseString] isEqualToString: clientWrapper.string]));
    
    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

- (void) testRegularRebasePerformance
{
    const NSUInteger objectsToInsert = 80;
    
    OrderedGroupNoOpposite *serverGroup = [[OrderedGroupNoOpposite alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
    [(UnorderedGroupNoOpposite *)serverBranch.rootObject setContents: S(serverGroup)];
    [serverPersistentRoot commit];
    
    [transport deliverMessagesToClient];
    
    // several commits on client
    
    OrderedGroupNoOpposite *clientGroup = [[(UnorderedGroupNoOpposite *)clientBranch.rootObject contents] anyObject];
    for (NSUInteger i = 0; i < objectsToInsert; i++)
    {
        OrderedGroupNoOpposite *child = [[OrderedGroupNoOpposite alloc] initWithObjectGraphContext: clientBranch.objectGraphContext];
        child.label = (@(i)).stringValue;
        [[clientGroup mutableArrayValueForKey: @"contents"] addObject: child];
        [clientPersistentRoot commit];
    }
    UKIntsEqual(objectsToInsert, clientGroup.contents.count);
    
    // 1 commit on server
    
    {
        OrderedGroupNoOpposite *child = [[OrderedGroupNoOpposite alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
        child.label = @"serverChild";
        [[serverGroup mutableArrayValueForKey: @"contents"] insertObject: child atIndex: 0];
        [serverPersistentRoot commit];
    }
    
    // deliver first client commit to server. This will be the first character of 'charactersToInsert'
    [transport deliverMessagesToServer];
    
    // Merge in the server's changes on the client
    [transport deliverMessagesToClient];
    
    // Send confirmation to server
    [transport deliverMessagesToServer];
    
    // Send confirmation back to client
    [transport deliverMessagesToClient];
    
    UKIntsEqual(objectsToInsert + 1, clientGroup.contents.count);
    UKIntsEqual(objectsToInsert + 1, serverGroup.contents.count);
    
    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

@end

