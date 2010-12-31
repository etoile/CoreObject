#import "Application.h"


@implementation Application

- (void)sendEvent:(NSEvent *)event
{
	if (([event type] == NSKeyDown || [event type] == NSKeyUp) && ![event isARepeat])
	{
		const unichar F1 = NSF1FunctionKey;
		if ([[event charactersIgnoringModifiers] isEqualToString:
			 [NSString stringWithCharacters: &F1 length:1]])
		{
			if ([event type] == NSKeyDown)
			{
				[[NSApp delegate] showShelf: self];
			}
			else
			{
				[[NSApp delegate] hideShelf: self];
			}
		}
	}
	[super sendEvent: event];
}

@end
