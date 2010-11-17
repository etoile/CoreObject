#include "LCQueryTermVector.h"
#include "LCAnalyzer.h"
#include "LCStringReader.h"
#include "GNUstep.h"

@interface LCQueryTermVector (LCPrivate)
- (void) processTerms: (NSArray *) queryTerms;
@end

@implementation LCQueryTermVector
- (id) init
{
	self = [super init];
	ASSIGN(terms, AUTORELEASE([[NSMutableArray alloc] init]));
	ASSIGN(termFreqs, AUTORELEASE([[NSMutableArray alloc] init]));
	return self;
}

- (void) dealloc
{
	DESTROY(terms);
	DESTROY(termFreqs);
	[super dealloc];
}

- (NSString *) field { return nil; }

- (id) initWithQueryTerms: (NSArray *) queryTerms
{
	self = [self init];
	[self processTerms: queryTerms];
	return self;
}

- (id) initWithString: (NSString *) queryString
			 analyzer: (LCAnalyzer *) analyzer
{
	self = [self init];
	if (analyzer != nil)
	{
          LCStringReader *sr = AUTORELEASE([[LCStringReader alloc] initWithString: queryString]);
		LCTokenStream *stream = [analyzer tokenStreamWithField: @"" reader: sr];
		if (stream != nil)
		{
			LCToken *next = nil;
			NSMutableArray *ts = AUTORELEASE([[NSMutableArray alloc] init]);
			while ((next = [stream nextToken]))
			{
				[ts addObject: [next termText]];
			}
			[self processTerms: ts];
		}
	}
	return self;
}

- (void) processTerms: (NSArray *) queryTerms
{
	if (queryTerms)
	{
		NSArray *newTerms = [queryTerms sortedArrayUsingSelector: @selector(compare:)];
		// filter out duplicates
		NSMutableArray *tmpList = [[NSMutableArray alloc] init];
		NSMutableArray *tmpFreqs = [[NSMutableArray alloc] init];
		int i;
		for (i = 0; i < [newTerms count]; i++)
		{
			NSString *term = [newTerms objectAtIndex: i];
			int position = [tmpList indexOfObject: term];
			if (position == NSNotFound)
			{
				[tmpList addObject: term];
				[tmpFreqs addObject: [NSNumber numberWithInt: 1]];
			}
			else
			{
				/* increase frequency */
				int integer = [[tmpFreqs objectAtIndex: position] intValue] + 1;
				[tmpFreqs replaceObjectAtIndex: position withObject: [NSNumber numberWithInt: integer]];
			}
		}
		ASSIGNCOPY(terms, tmpList);
		ASSIGNCOPY(termFreqs, tmpFreqs);
                DESTROY(tmpList);
                DESTROY(tmpFreqs);
	}
}

- (NSString *) description
{
	NSMutableString *sb = [[NSMutableString alloc] init];
	[sb appendString: @"{"];
	int i, count = [terms count];
	for (i = 0; i < count; i++)
	{
		if (i > 0) [sb appendString: @", "];
		[sb appendFormat: @"%@/%@", [terms objectAtIndex: i], [termFreqs objectAtIndex: i]];
	}
	[sb appendString: @"}"];
	return AUTORELEASE(sb);
}

- (int) size
{
	return [terms count];
}

- (NSArray *) allTerms
{
	return terms;
}

- (NSArray *) allTermFrequencies
{
	return termFreqs;
}

- (int) indexOfTerm: (NSString *) term
{
	int res = [terms indexOfObject: term];
	return (res >= 0) ? res : -1;
}

- (NSIndexSet *) indexesOfTerms: (NSArray *) ts
						  start: (int) start length: (int) len
{
	NSMutableIndexSet *res = [[NSMutableIndexSet alloc] init];
	int i;
	for (i = 0; i < len; i++) 
	{
		[res addIndex: [self indexOfTerm: [ts objectAtIndex: i]]];
	}
	return AUTORELEASE(res); 
}

@end
