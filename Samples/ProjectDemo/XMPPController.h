#import <Foundation/Foundation.h>

@interface XMPPController : NSObject

+ (XMPPController *) sharedInstance;

- (void) reconnect;

@end
