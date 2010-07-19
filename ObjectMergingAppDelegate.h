#import <Cocoa/Cocoa.h>

@interface ObjectMergingAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
    NSTextView *textView;
}

@property (assign) IBOutlet NSWindow *window;

@end
