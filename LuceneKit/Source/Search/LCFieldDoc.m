#include "LCFieldDoc.h"
#include "GNUstep.h"

@implementation LCFieldDoc

- (id) initWithDocument: (int) d
				  score: (float) s fields: (NSArray *) f
{
	self = [self initWithDocument: d score: s];
	[self setFields: f];
	return self;
}

- (void) dealloc
{
	DESTROY(fields);
	[super dealloc];
}

- (NSArray *) fields
{
	return fields;
}

- (void) setFields: (NSArray *) f
{
	ASSIGNCOPY(fields, f);
}

@end
