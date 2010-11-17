#include "LCHits.h"
#include "LCSearcher.h"
#include "LCFilter.h"
#include "LCSort.h"
#include "LCQuery.h"
#include "LCTopDocs.h"
#include "LCScoreDoc.h"
#include "LCHitIterator.h"
#include "LCDocument.h"
#include "GNUstep.h"

@interface LCHits (LCPrivate)
- (void) moreDocuments: (int) min;
- (LCHitDocument *) hitDocument: (int) n;
- (void) addToFront: (LCHitDocument *) hitDoc;
- (void) remove: (LCHitDocument *) hitDoc;
@end

@implementation LCHits
- (id) init
{
	self = [super init];
	filter = nil;
	sort = nil;
	hitDocs = [[NSMutableArray alloc] init];
	numDocs = 0;
	maxDocs = 200;
	return self;
}

- (void) dealloc
{
	DESTROY(hitDocs);
	DESTROY(weight);
	DESTROY(searcher);
	DESTROY(filter);
	DESTROY(sort);
        //Clean retain/release prev/next
        if (first)
          {
            LCHitDocument *hitDoc=first;
            while(hitDoc)
              {
                LCHitDocument *nextHitDoc=[hitDoc next];
                //No need to retain it because last one retain previouses
                [hitDoc setNext:nil];
                [nextHitDoc setPrev:nil];
                hitDoc=nextHitDoc;
              }
          }
	DESTROY(first);
	DESTROY(last);
	[super dealloc];
}

- (id) initWithSearcher: (LCSearcher *) s
				  query: (LCQuery *) q
				 filter: (LCFilter *) f
{
	self = [self init];
	ASSIGN(weight, [q weight: s]);
	ASSIGN(searcher, s);
	ASSIGN(filter, f);
	[self moreDocuments: 50]; // retrieve 100 initially
	return self;
}

- (id) initWithSearcher: (LCSearcher *) s
				  query: (LCQuery *) q
				 filter: (LCFilter *) f
				   sort: (LCSort *) o
{
	self = [self init];
	ASSIGN(weight, [q weight: s]);
	ASSIGN(searcher, s);
	ASSIGN(filter, f);
	ASSIGN(sort, o);
	[self moreDocuments: 50]; // retrieve 100 initially
	return self;
}

- (void) moreDocuments: (int)  min
{
	CREATE_AUTORELEASE_POOL(pool);
	if ([hitDocs count] > min) {
		min = [hitDocs count];
	}
	
	int n = min * 2; // double # retrieved
	LCTopDocs *topDocs;
	if (sort) {
		topDocs = (LCTopDocs *)[searcher search: weight filter: filter maximum: n sort: sort];
	}
	else {
		topDocs = [searcher search: weight filter: filter maximum: n];
	}
	
	length = [topDocs totalHits];
	NSArray * scoreDocs = [topDocs scoreDocuments];
	
	float scoreNorm = 1.0f;
	if (length > 0 && [topDocs maxScore] > 1.0f)
	{
		scoreNorm = 1.0f / [topDocs maxScore];
	}
	
	int end = ([scoreDocs count] < length) ? [scoreDocs count] : length;
	int i;
	for (i = [hitDocs count]; i < end; i++)
	{
		LCHitDocument *newDoc = [[LCHitDocument alloc] initWithScore: ([[scoreDocs objectAtIndex: i] score] * scoreNorm) 
														  identifier: [(LCScoreDoc *)[scoreDocs objectAtIndex: i] document]];
		[hitDocs addObject: newDoc];
		RELEASE(newDoc);
	}
	DESTROY(pool);
}

- (NSUInteger) count 
{
	return length;
}

- (LCDocument *) document: (int) n
{
	LCHitDocument *hitDoc = [self hitDocument: n];
	RETAIN(hitDoc);
	
	// Update LRU cache of documents
	[self remove: hitDoc];               // remove from list, if there
	[self addToFront: hitDoc];           // add to front of list
	RELEASE(hitDoc);
	
	if (numDocs > maxDocs) {      // if cache is full
		LCHitDocument *oldLast = last;
		[self remove: last];             // flush last
		[oldLast setDocument: nil];       // let doc get gc'd
	}
	
	if ([hitDoc document] == nil) {
		[hitDoc setDocument: [searcher document: [hitDoc identifier]]];  // cache miss: read document
	}
	return [hitDoc document];
}

- (float) score: (int) n
{
	return [[self hitDocument: n] score];
}

- (int) identifier: (int) n
{
	return [[self hitDocument: n] identifier];
}

- (LCHitIterator *) iterator
{
	return AUTORELEASE([[LCHitIterator alloc] initWithHits: self]);
}

- (LCHitDocument *) hitDocument: (int) n
{
	if (n >= length) {
		NSLog(@"Not a valid hit number: %d", n);
		return nil;
	}
	
	if (n >= [hitDocs count]) {
		[self moreDocuments: n];
	}
	
	return [hitDocs objectAtIndex: n];
}

- (void) addToFront: (LCHitDocument *) hitDoc
{
	if (first == nil) {
		ASSIGN(last, hitDoc);
	} else {
		[first setPrev: hitDoc];
	}
	
	[hitDoc setNext: first];
	ASSIGN(first, hitDoc);
	[hitDoc setPrev: nil];
	
	numDocs++;
}

- (void) remove: (LCHitDocument *) hitDoc
{
	if ([hitDoc document] == nil) { // it's not in the list
		return; // abort
	}
	
	if ([hitDoc next] == nil) {
		ASSIGN(last, [hitDoc prev]);
	} else {
		[[hitDoc next] setPrev: [hitDoc prev]];
	}
	
	if ([hitDoc prev] == nil) {
		ASSIGN(first, [hitDoc next]);
	} else {
		[[hitDoc prev] setNext: [hitDoc next]];
	}
	
	numDocs--;
}

@end

@implementation LCHitDocument
- (id) initWithScore: (float) s identifier: (int) i
{
	self = [self init];
	score = s;
	identifier = i;
	return self;
}

- (void) dealloc
{
	DESTROY(prev);
	DESTROY(next);
	DESTROY(doc);
	[super dealloc];
}

- (LCHitDocument *) prev { return prev; };
- (void) setPrev: (LCHitDocument *) d
{
	if (d == nil)
		DESTROY(prev);
	else
		ASSIGN(prev, d);
}
- (LCHitDocument *) next { return next; };
- (void) setNext: (LCHitDocument *) d
{
	if (d == nil)
		DESTROY(next);
	else
		ASSIGN(next, d);
}
- (float) score { return score; };
- (int) identifier { return identifier; };
- (LCDocument *) document { return doc; };
- (void) setDocument: (LCDocument *) d
{
	if (d == nil)
		DESTROY(doc);
	else
		ASSIGN(doc, d);
}

@end
