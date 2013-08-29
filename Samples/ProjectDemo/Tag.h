#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface Tag : COObject
{
	NSString *label;
}

- (NSString*)label;
- (void)setLabel:(NSString *)l;

@end