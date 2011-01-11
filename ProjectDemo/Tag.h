#import <Cocoa/Cocoa.h>
#import "COObject.h"

@interface Tag : COObject
{
	NSString *label;
}

- (NSString*)label;
- (void)setLabel:(NSString *)l;

@end