#include "LCTermScorer.h"
#include "LCTermQuery.h"
#include "GNUstep.h"
#include <limits.h>

static int SCORE_CACHE_SIZE = 32;

@implementation LCTermScorer

- (id) init
{
	self = [super init];
	docs = [[NSMutableArray alloc] init];
	freqs = [[NSMutableArray alloc] init];
	scoreCache = [[NSMutableArray alloc] init];
	pointer = 0;
	pointerMax = 0;
	return self;
}

- (id) initWithWeight: (id <LCWeight>) w termDocuments: (id <LCTermDocuments>) td
		   similarity: (LCSimilarity *) s norms: (NSData *) n
{
	self = [self initWithSimilarity: s];
	ASSIGN(weight, w);
	ASSIGN(termDocs, td);
	ASSIGN(norms, n);
	weightValue = [weight value];
	
	int i;
	for (i = 0; i < SCORE_CACHE_SIZE; i++)
	{
		float f = [[self similarity] termFrequencyWithInt: i] * weightValue;
		[scoreCache addObject: [NSNumber numberWithFloat: f]];
	}
	return self;
}

- (void) dealloc
{
	DESTROY(weight);
	DESTROY(termDocs);
	DESTROY(norms);
	DESTROY(docs);
	DESTROY(freqs);
	DESTROY(scoreCache);
	[super dealloc];
}

- (void) score: (LCHitCollector *) hc
{
	[self next];
	[self score: hc maximalDocument: INT_MAX];
}

- (BOOL) score: (LCHitCollector *) hc maximalDocument: (int) max
{
	LCSimilarity *s = [self similarity]; // cache sim in local
	float *normDecoder = [LCSimilarity normDecoder];
	while (doc < max) { // for docs in window
		int f = [[freqs objectAtIndex: pointer] intValue];
		float score = (f < SCORE_CACHE_SIZE) ? [[scoreCache objectAtIndex: f] floatValue] : [s termFrequencyWithInt: f]*weightValue;
		char *n = (char *)[norms bytes];
		score *= normDecoder[n[doc] & 0xFF]; // normalize for field
		
		[hc collect: doc score: score]; // collect score
		
		if (++pointer >= pointerMax) {
			pointerMax = [termDocs readDocuments: docs frequency: freqs size: SCORE_CACHE_SIZE];
			if (pointerMax != 0) {
				pointer = 0;
			} else {
				[termDocs close]; // close stream
				doc = INT_MAX; // set to sentinel value
				return NO;
			}
		}
		doc = [[docs objectAtIndex: pointer] intValue];
	}
	return YES;
}

- (int) document { return doc; }

- (BOOL) next
{
	pointer++;
	if (pointer >= pointerMax) {
		pointerMax = [termDocs readDocuments: docs frequency: freqs size: SCORE_CACHE_SIZE]; // refill buffer
		if (pointerMax != 0) {
			pointer = 0;
		} else {
			[termDocs close]; // close stream
			doc = INT_MAX; // set to sentinel value
			return NO;
		}
	}
	doc = [[docs objectAtIndex: pointer] intValue];
	return YES;
}

- (float) score
{
	int f = [[freqs objectAtIndex: pointer] intValue];
	float raw = (f < SCORE_CACHE_SIZE) ? [[scoreCache objectAtIndex: f] floatValue] : [[self similarity] termFrequencyWithInt: f] * weightValue;
	char *n = (char *)[norms bytes];
	return raw * [LCSimilarity decodeNorm: n[doc]]; // normalize for field
}

- (BOOL) skipTo: (int) target
{
	for (pointer++; pointer < pointerMax; pointer++) {
		if ([[docs objectAtIndex: pointer] intValue] >= target) {
			doc = [[docs objectAtIndex: pointer] intValue];
			return YES;
		}
	}
	
	BOOL result = [termDocs skipTo: target];
	if (result) {
		pointerMax = 1;
		pointer = 0;
		doc = [termDocs document];
		/* LuceneKit: pointer == 0 */
		if (pointer < [docs count])
		{
			[docs replaceObjectAtIndex: pointer 
							withObject: [NSNumber numberWithInt: doc]];
			[freqs replaceObjectAtIndex: pointer 
							 withObject: [NSNumber numberWithFloat: [termDocs frequency]]];
		}
		else
		{
			[docs addObject: [NSNumber numberWithInt: doc]];
			[freqs addObject: [NSNumber numberWithFloat: [termDocs frequency]]];
		}
	} else {
		doc = INT_MAX;
	}
	return result;
}

- (LCExplanation *) explain: (int) document
{
	LCTermQuery *query = (LCTermQuery *)[weight query];
	LCExplanation *tfExplanation = [[LCExplanation alloc] init];
	int tf = 0;
	while (pointer < pointerMax) {
		if ([[docs objectAtIndex: pointer] intValue] == document)
			tf = [[freqs objectAtIndex: pointer] floatValue];
		pointer++;
	}
	if (tf == 0) {
		while ([termDocs hasNextDocument]) {
			if ([termDocs document] == document) {
				tf = [termDocs frequency];
			}
		}
	}
	[termDocs close];
	[tfExplanation setValue: [[self similarity] termFrequencyWithInt: tf]];
	[tfExplanation setRepresentation: [NSString stringWithFormat: @"tf(termFreq(%@)=%d)", [query term], tf]];
	return AUTORELEASE(tfExplanation);
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"LCTermScorer: scorer(%@)", weight];
}

@end
