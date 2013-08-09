#import <Cocoa/Cocoa.h>

@interface EWPickboardWindowController : NSWindowController
{
}

+ (EWPickboardWindowController *) sharedController;

- (void) show;

@end
