/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  March 2014
    License:  MIT  (see COPYING)
 */

#ifndef GNUSTEP

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"
#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiffPerformance : EditingContextTestCase <UKTest>
@end


@implementation TestAttributedStringDiffPerformance

- (COObjectGraphContext *)make1KChunkAttributedString
{
    COObjectGraphContext *result = [COObjectGraphContext new];
    COAttributedString *attrStr = [[COAttributedString alloc] initWithObjectGraphContext: result];
    result.rootObject = attrStr;

    NSMutableArray *chunksArray = [NSMutableArray new];

    for (NSUInteger i = 0; i < 1000; i++)
    {
        COAttributedStringChunk *chunk = [[COAttributedStringChunk alloc] initWithObjectGraphContext: result];
        chunk.text = (i % 2 == 0) ? @"xxx" : @"yyy";
        [chunksArray addObject: chunk];
    }

    attrStr.chunks = chunksArray;

    return result;
}

- (NSTimeInterval)timeToCopyObjectGraph: (COObjectGraphContext *)objectGraph
{
    NSDate *start = [NSDate date];
    COObjectGraphContext *tempObjectGraph = [COObjectGraphContext new];

    (void)[[COCopier new] copyItemWithUUID: objectGraph.rootItemUUID
                                 fromGraph: objectGraph
                                   toGraph: tempObjectGraph];

    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start];
    return time;
}

- (NSTimeInterval)timeToDiffAttributedString: (COAttributedString *)as1
                        withAttributedString: (COAttributedString *)as2
{
    NSDate *start = [NSDate date];

    (void)[[COAttributedStringDiff alloc] initWithFirstAttributedString: as1
                                                 secondAttributedString: as2
                                                                 source: nil];

    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start];
    return time;
}

- (void)testDiffPerformance
{
    COObjectGraphContext *ctx1 = [self make1KChunkAttributedString];
    COObjectGraphContext *ctx2 = [self make1KChunkAttributedString];

    COAttributedString *as1 = ctx1.rootObject;
    COAttributedString *as2 = ctx2.rootObject;

    [self appendHTMLString: @"<I>test</I>" toAttributedString: as2];

    NSTimeInterval diffTime = [self timeToDiffAttributedString: as1 withAttributedString: as2];
    NSTimeInterval copyTime = [self timeToCopyObjectGraph: ctx1];

    const double diffTimesFaster = copyTime / diffTime;
    UKTrue(diffTimesFaster >= 5);

    NSLog(@"COAttributedStringDiff diff with a trivial insertion and %d chunks took %d ms. Copying %d objects took %d ms. Expected diff to be at least 5x faster than copy, was %f x faster.",
          (int)as1.chunks.count,
          (int)(diffTime * 1000),
          (int)ctx1.itemUUIDs.count,
          (int)(copyTime * 1000),
          diffTimesFaster);
}

@end

#endif
