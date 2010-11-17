#include "LCLowerCaseFilter.h"

/**
* Normalizes token text to lower case.
 *
 * @version $Id$
 */
@implementation LCLowerCaseFilter

- (LCToken *) nextToken
{
	LCToken *t = [input nextToken];
	
	if (t == nil)
		return nil;
	
	NSString *s = [[t termText] lowercaseString];
	[t setTermText: s];
	
	return t;
}

@end
