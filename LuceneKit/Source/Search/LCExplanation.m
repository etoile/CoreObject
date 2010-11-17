#include "LCExplanation.h"
#include "GNUstep.h"

/** Expert: Describes the score computation for document and query. */
@interface LCExplanation (LCPrivate)
- (NSString *) descriptionWithDepth: (int) depth;
@end

@implementation LCExplanation

- (id) initWithValue: (float) v representation: (NSString *) d
{
	self = [super init];
	[self setValue: v];
	[self setRepresentation: d];
	return self;
}

- (void) dealloc
{
	DESTROY(representation);
	DESTROY(details);
	[super dealloc];
}

/** The value assigned to this explanation node. */
- (float) value { return value; }
	/** Sets the value assigned to this explanation node. */
- (void) setValue: (float) v { value = v; }

	/** A description of this explanation node. */
- (NSString *) representation { return representation; }
	/** Sets the description of this explanation node. */

- (void) setRepresentation: (NSString *) d
{
	ASSIGN(representation, d);
}

/** The sub-nodes of this explanation node. */
- (NSArray *) details
{
	if (details == nil) return nil;
	return AUTORELEASE([details copy]);
	//  return (Explanation[])details.toArray(new Explanation[0]);
}

/** Adds a sub-node to this explanation node. */
- (void) addDetail: (LCExplanation *) detail
{
	if (details == nil)
		ASSIGN(details, AUTORELEASE([[NSMutableArray alloc] init]));
	[details addObject: detail];
}

/** Render an explanation as text. */
- (NSString *) description
{
	return [self descriptionWithDepth: 0];
}

- (NSString*) descriptionWithDepth: (int) depth
{
	NSMutableString *s = [[NSMutableString alloc] init];
	int i;
	for (i = 0; i < depth; i++) {
		[s appendString: @"  "];
	}
	[s appendFormat: @"%f = %@\n", [self value], [self representation]];
	
	NSArray *array = [self details];
	if (array != nil) {
		for (i = 0 ; i < [array count]; i++) {
			[s appendString: [[array objectAtIndex: i] descriptionWithDepth: depth+1]];
		}
    }
	
	return AUTORELEASE(s);
}

/** Render an explanation as HTML. */
- (NSString *) descriptionWithHTML
{
	NSMutableString *s = [[NSMutableString alloc] init];
	[s appendString: @"<ul>\n"];
	[s appendFormat: @"<li>%f = %@</li>\n", [self value], [self representation]];
	
	NSArray *array = [self details];
	int i;
	if (array != nil) {
		for (i = 0 ; i < [array count]; i++) {
			[s appendString: [[array objectAtIndex: i] descriptionWithHTML]];
		}
	}
	
	[s appendString: @"</ul>\n"];
	return AUTORELEASE(s);
}

@end
