#include "LCTopFieldDocs.h"
#include "GNUstep.h"

@implementation LCTopFieldDocs
- (id) initWithTotalHits: (int) th
		  scoreDocuments: (NSArray *) sd
			  sortFields: (NSArray *) f
			maxScore: (float) max
{
	self = [self initWithTotalHits: th scoreDocuments: sd maxScore: max];
	ASSIGN(fields, f);
	return self;
}

- (void) dealloc
{
	DESTROY(fields);
	[super dealloc];
}
@end
