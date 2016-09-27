/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <UnitKit/UKRunner.h>
#import <UnitKit/UKTestHandler.h>
#import "TestCommon.h"

int main (int argc, const char *argv[])
{
    @autoreleasepool {
        NSLog(@"Store URL: %@", [EditingContextTestCase storeURL]);
        
        UKRunner *runner = [UKRunner new];
        
        UKTestHandler *handler = [UKTestHandler handler];
        [handler setQuiet: YES];
        
        [runner runTestsWithClassNames: nil principalClass: [EditingContextTestCase class]];
        [runner reportTestResults];
        
        if ([handler exceptionsReported] > 0 || [handler testsFailed] > 0)
        {
            return 1;
        }
        else
        {
            return 0;
        }
    }
}
