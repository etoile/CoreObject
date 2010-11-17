#import <Cocoa/Cocoa.h>


@interface CONamedBranch : NSObject
{
	NSString *name;
	ETUUID *uuid;
}

- (ETUUID*)UUID;

- (NSString *)name;
- (void)setName: (NSString*)name;

@end
