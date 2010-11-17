#include "LCStopFilter.h"
#include "GNUstep.h"

/**
* Removes stop words from a token stream.
 */

@implementation LCStopFilter
/**
* Builds a Set from an array of stop words,
 * appropriate for passing into the StopFilter constructor.
 * This permits this stopWords construction to be cached once when
 * an Analyzer is constructed.
 */
+ (NSSet *) makeStopSet: (NSArray *) sw // Array of String
{
	NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity: [sw count]];
	int i, count = [sw count];
	for(i = 0; i < count; i++)
    {
		[set addObject: [sw objectAtIndex: i]];
    }
	return AUTORELEASE(set);
}

/**
* Constructs a filter which removes words from the input
 * TokenStream that are named in the array of words.
 */
- (id) initWithTokenStream: (LCTokenStream *) stream
          stopWordsInArray: (NSArray *) sw
{
	return [self initWithTokenStream: stream
					  stopWordsInSet: [LCStopFilter makeStopSet: sw]];
}

/**
* Constructs a filter which removes words from the input
 * TokenStream that are named in the Set.
 * It is crucial that an efficient Set implementation is used
 * for maximum performance.
 *
 * @see #makeStopSet(java.lang.String[])
 */
- (id) initWithTokenStream: (LCTokenStream *) stream
            stopWordsInSet: (NSSet *) sw
{
	self = [super initWithTokenStream: stream];
	stopWords = [[NSSet alloc] initWithSet: sw];
	return self;
}

- (void) dealloc
{
	DESTROY(stopWords);
	[super dealloc];
}

/**
* Returns the next input Token whose termText() is not a stop word.
 */
- (LCToken *) nextToken
{
	// return the first non-stop word found
	LCToken *t = nil;
	while((t = [input nextToken]))
    {
		if (![stopWords containsObject: [t termText]])
			return t;
    }
	return nil;
}

@end
