#include "LCSegmentTermPositionVector.h"
#include "GNUstep.h"

@implementation LCSegmentTermPositionVector
- (id) initWithField: (NSString *) f
               terms: (NSArray *) ts
           termFreqs: (NSArray *) tf
           positions: (NSArray *) pos
             offsets: (NSArray *) off
{
	self = [super initWithField: f terms: ts termFreqs: tf];
	positions = [[NSMutableArray alloc] initWithArray: pos];
	offsets = [[NSMutableArray alloc] initWithArray: off];
	return self;
}

- (void) dealloc
{
	DESTROY(positions);
	DESTROY(offsets);
	[super dealloc];
}

/**
* Returns an array of TermVectorOffsetInfo in which the term is found.
 *
 * @param index The position in the array to get the offsets from
 * @return An array of TermVectorOffsetInfo objects or the empty list
 * @see org.apache.lucene.analysis.Token
 */
- (NSArray *) termOffsets: (int) index
{
	if (offsets == nil) return nil;
	/* LuceneKit: Not sure */
	if ([offsets count] == 0) return nil;
	
	NSMutableArray *result = [[NSMutableArray alloc] init];
	if (index >= 0 && index < [offsets count])
    {
		[result setArray: [offsets objectAtIndex: index]];
    }
	return AUTORELEASE(result);;
}

/**
* Returns an array of positions in which the term is found.
 * Terms are identified by the index at which its number appears in the
 * term String array obtained from the <code>indexOf</code> method.
 */
- (NSArray *) termPositions: (int) index
{
	if(positions == nil)
		return nil;
	
	/* LuceneKit: not sure */
	if ([positions count] == 0) return nil;
	
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	if (index >= 0 && index < [positions count])
    {
		[result setArray: [positions objectAtIndex: index]];
    }
    
	return AUTORELEASE(result);
}

@end
