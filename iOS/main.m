/*
    Copyright (C) 2014 Quentin Mathe

    Date:  February 2014
    License: Modified BSD (see COPYING)
 */

#import <UIKit/UIKit.h>
#import <UnitKit/UnitKit.h>

int main(int argc, char *argv[])
{
    int status = EXIT_FAILURE;

    @autoreleasepool
    {
        UKRunner *runner = [UKRunner new];

        [[UKTestHandler handler] setQuiet: YES];

        [runner runTestsInBundle: [NSBundle mainBundle]];
        status = [runner reportTestResults];
    }

    return status;
}
