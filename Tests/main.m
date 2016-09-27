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
    int status = 0;
    
    @autoreleasepool {
        NSLog(@"Store URL: %@", [EditingContextTestCase storeURL]);
        
        UKRunner *runner = [UKRunner new];

        UKTestHandler *handler = [UKTestHandler handler];
        [handler setQuiet: YES];
        
        [runner runTestsWithClassNames: nil
                        principalClass: [EditingContextTestCase class]];
        [runner reportTestResults];

        if ([handler exceptionsReported] > 0 || [handler testsFailed] > 0)
        {
            status = 1;
        }
    }

    return status;
}
