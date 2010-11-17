#include "LCSegmentTermVector.h"
#include "GNUstep.h"

@implementation LCSegmentTermVector

- (id) initWithField: (NSString *) s
               terms: (NSArray *) t
	       termFreqs: (NSArray *) f
{
	self = [self init];
	ASSIGN(field, s);
	terms = [[NSMutableArray alloc] initWithArray: t];
	termFreqs = [[NSMutableArray alloc] initWithArray: f];
	return self;
}

- (void) dealloc
{
	DESTROY(terms);
	DESTROY(termFreqs);
	DESTROY(field);
	[super dealloc];
}

/**
* 
 * @return The number of the field this vector is associated with
 */
- (NSString *) field
{
	return field;
}

- (NSString *) description
{
	NSMutableString *sb = [[NSMutableString alloc] init];
	[sb appendFormat: @"{%@: ", field];
	int i;
	if(terms != nil)
    {
		for (i = 0; i < [terms count]; i++) 
        {
			if (i > 0) [sb appendString: @", "];
			[sb appendFormat: @"%@/%@", [terms objectAtIndex: i], [termFreqs objectAtIndex: i]];
        }
    }
	[sb appendString: @"}"];
    
	return AUTORELEASE(sb);
}

- (int) size
{
	return terms == nil? 0 : [terms count];
}

- (NSArray *) allTerms
{
	return terms;
}

- (NSArray *) allTermFrequencies
{
	return termFreqs;
}

- (int) indexOfTerm: (NSString *) text
{
	if (terms == nil)
		return -1;
	return [terms indexOfObject: text];
}

- (NSIndexSet *) indexesOfTerms: (NSArray *) termNumbers
						  start: (int) start length: (int) len
// TODO: there must be a more efficient way of doing this.
//       At least, we could advance the lower bound of the terms array
//       as we find valid indexes. Also, it might be possible to leverage
//       this even more by starting in the middle of the termNumbers array
//       and thus dividing the terms array maybe in half with each found index.
{
	int i;
	NSMutableIndexSet *a = [[NSMutableIndexSet alloc] init];
	id object;
	
	for (i = 0; i < len; i++) 
    {
		object = [termNumbers objectAtIndex: (start + i)];
		[a addIndex: [self indexOfTerm: object]];
    }
	return AUTORELEASE(a);
}

@end
