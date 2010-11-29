#import <Foundation/Foundation.h>
#import <UnitKit/UKRunner.h>
#import <UnitKit/UKTestHandler.h>
#import "TestCommon.h"

@interface StatusPrinter : NSObject
{
	unsigned int warnings;
}
- (void) reportWarning:(NSString *)message;
- (void) printStatus;
@end

@implementation StatusPrinter

- (void) reportWarning:(NSString *)message
{
	warnings++;
	NSLog(@"%@", message);
}

- (void) printStatus
{	
	NSLog(@"%d passed, %d failed, %d warnings", [[UKTestHandler handler] testsPassed], [[UKTestHandler handler] testsFailed], warnings);
}

@end


int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	setUpMetamodel();
	
	StatusPrinter *stats = [StatusPrinter new];
	[[UKTestHandler handler] setDelegate: stats];
	//[[UKTestHandler handler] setQuiet: YES];
	
	UKRunner *runner = [UKRunner new];
	[runner runTestsInBundle: [NSBundle mainBundle]];
	
	[stats printStatus];
	
    [pool drain];
    return 0;
}
