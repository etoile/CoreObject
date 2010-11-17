#include "LCHitCollector.h"
#include "GNUstep.h"

@implementation LCHitCollector
- (void) collect: (int) doc score: (float) score 
{
	if ((target == nil) || (selector == NULL)) return;
	NSMethodSignature *signature = [target methodSignatureForSelector: selector];
	/* Make sure there are 4 arguments: self, _cmd, doc, score */
	if ([signature numberOfArguments] != 4) 
	{
		NSLog(@"Wrong number of arguments");
		return;
	}
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: signature];
	[invocation setTarget: target];
	[invocation setSelector: selector];
	[invocation setArgument: &doc atIndex: 2];
	[invocation setArgument: &score atIndex: 3];
	[invocation invoke];
}

- (void) setTarget: (id) t
{
	ASSIGN(target, t);
}
- (void) setSelector: (SEL) s
{
	selector = s;
}
- (id) target { return target; }
- (SEL) selector { return selector; }

- (void) dealloc
{
	DESTROY(target);
	[super dealloc];
}
@end
