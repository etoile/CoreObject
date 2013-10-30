#import "XMPPController.h"

@implementation XMPPController

+ (XMPPController *) sharedInstance
{
    static XMPPController *sharedInstance;
    if (sharedInstance == nil)
    {
        sharedInstance = [[XMPPController alloc] init];
    }
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self reconnect];
    }
    return self;
}

- (void) reconnect
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *jid = [defs stringForKey: @"XMPPJID"];
	NSString *password	= [defs stringForKey: @"XMPPPassword"];
	NSString *server = [defs stringForKey: @"XMPPServer"];
	
	NSLog(@"Connect to %@ %@ %@", jid, password, server);
}

@end
