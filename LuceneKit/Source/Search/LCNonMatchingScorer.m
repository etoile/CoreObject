#include "LCNonMatchingScorer.h"
#include "GNUstep.h"

@implementation LCNonMatchingScorer
- (int) document 
{ 
	//NSLog(@"Not supported"); 
	return -1; 
}

- (BOOL) next 
{ 
	//NSLog(@"Not supported"); 
	return NO; 
}

- (float) score 
{ 
	//NSLog(@"Not supported"); 
	return -1; 
}

- (BOOL) skipTo: (int) target 
{ 
	return NO; 
}

- (LCExplanation *) explain: (int) document
{
	LCExplanation *e = [[LCExplanation alloc] init];
	[e setRepresentation: @"No document matches."];
	return AUTORELEASE(e);
}
@end
