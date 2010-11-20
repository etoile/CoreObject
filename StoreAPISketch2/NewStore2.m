#import <Foundation/Foundation.h>
#import <UnitKit/UKRunner.h>

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	[[UKRunner new] runTestsInBundle: [NSBundle mainBundle]];
	
    [pool drain];
    return 0;
}
