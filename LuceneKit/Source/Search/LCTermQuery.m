#include "LCTermQuery.h"
#include "LCTermScorer.h"
#include "LCSimilarity.h"
#include "LCSearcher.h"
#include "LCTerm.h"
#include "LCTermDocs.h"
#include "LCSmallFloat.h"
#include "NSString+Additions.h"
#include "GNUstep.h"

@interface LCTermWeight: NSObject <LCWeight>
{
	LCSimilarity *similarity;
	LCTermQuery *query;
	float value;
	float idf;
	float queryNorm;
	float queryWeight;
}
- (id) initWithTermQuery: (LCTermQuery *) query
				searcher: (LCSearcher *) searcher;
@end


@implementation LCTermQuery
- (id) initWithTerm: (LCTerm *) t
{
	self = [super init];
	ASSIGN(term, t);
	return self;
}

- (void) dealloc
{
	DESTROY(term);
	[super dealloc];
}

- (id <LCWeight>) createWeight: (LCSearcher *) searcher
{
	return AUTORELEASE([[LCTermWeight alloc] initWithTermQuery: self searcher: searcher]);
}

- (void) extractTerms: (NSMutableArray *) terms
{
	[terms addObject: [self term]];
}

- (LCTerm *) term { return term; }

- (NSString *) descriptionWithField: (NSString *) field
{
	NSMutableString *buffer = [[NSMutableString alloc] init];
	if (![[term field] isEqualToString: field]) {
		[buffer appendString: [term field]];
		[buffer appendString: @":"];
	}
	[buffer appendString: [term text]];
	[buffer appendString: LCStringFromBoost([self boost])];
	return AUTORELEASE(buffer);
}

- (BOOL) isEqual: (id) o
{
	if (![o isKindOfClass: [self class]])
		return NO;
	LCTermQuery *other = (LCTermQuery *)o;
	if (([self boost] == [other boost]) &&
		[term isEqual: [other term]])
		return YES;
	else
		return NO;
}

- (NSUInteger) hash
{
	// LuceneKit: should work. Otherwise, look LCSimilarity for implmentation of floatToIntbits()
	//return (int)[self boost] ^ [term hash];
	return FloatToIntBits([self boost]) ^ [term hash];
	// Float.floatToIntBits(getBoost()) ^ term.hashCode();
}

@end

@implementation LCTermWeight
- (id) initWithTermQuery: (LCTermQuery *) q
				searcher: (LCSearcher *) s
{
	self = [super init];
	ASSIGN(query, q);
	ASSIGN(similarity, [query similarity: s]);
	idf = [similarity inverseDocumentFrequencyWithTerm: [query term]
											  searcher: s];
	return self;
}

- (void) dealloc
{
	DESTROY(query);
	DESTROY(similarity);
	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"weight(0x%x)", self];
}

- (LCQuery *) query { return query; }
- (float) value { return value; }
- (float) sumOfSquaredWeights
{
	queryWeight = idf * [query boost]; // compute query weight
	return queryWeight * queryWeight; // square it
}

- (void) normalize: (float) norm
{
	queryNorm = norm;
	queryWeight *= queryNorm;  // normalize query weight
	value = queryWeight * idf; // idf for document
}

- (LCScorer *) scorer: (LCIndexReader *) reader
{
	id <LCTermDocuments> termDocs = [reader termDocumentsWithTerm: [query term]];
	if (termDocs == nil) return nil;
	LCTermScorer *scorer = [[LCTermScorer alloc] initWithWeight: self
													   termDocuments: termDocs similarity: similarity
														  norms: [reader norms: [[query term] field]]];
	return AUTORELEASE(scorer);
}

- (LCExplanation *) explain: (LCIndexReader *) reader
				   document: (int) doc
{
	LCExplanation *result = [[LCExplanation alloc] init];
	[result setRepresentation: [NSString stringWithFormat: @"weight(%@ in %d), product of:", query, doc]];
	
	LCExplanation *idfExpl = AUTORELEASE(([[LCExplanation alloc] initWithValue: idf representation: [NSString stringWithFormat: @"idf(docFreq=%d)", [reader documentFrequency: [query term]]]]));
	// explain query weight
	LCExplanation *queryExpl = AUTORELEASE([[LCExplanation alloc] init]);
	[queryExpl setRepresentation: [NSString stringWithFormat: @"queryWeight(%@), product of:", query]];
	
	LCExplanation *boostExpl = AUTORELEASE([[LCExplanation alloc] initWithValue: [query boost] representation: @"boost"]);
	if ([query boost] != 1.0f)
		[queryExpl addDetail: boostExpl];
	[queryExpl addDetail: idfExpl];
	
	LCExplanation *queryNormExpl = AUTORELEASE([[LCExplanation alloc] initWithValue: queryNorm representation: @"queryNorm"]);
	[queryExpl addDetail: queryNormExpl];
	
	[queryExpl setValue: [boostExpl value]+[idfExpl value]+[queryNormExpl value]];
	[result addDetail: queryExpl];
	// explain field weight
	NSString *field = [[query term] field];
	LCExplanation *fieldExpl = AUTORELEASE([[LCExplanation alloc] init]);
	[fieldExpl setRepresentation: [NSString stringWithFormat: @"fieldWeight(%@ in %d), product of:", [query term], doc]];
	LCExplanation *tfExpl = [[self scorer: reader] explain: doc];
	[fieldExpl addDetail: tfExpl];
	[fieldExpl addDetail: idfExpl];
	
	LCExplanation *fieldNormExpl = AUTORELEASE([[LCExplanation alloc] init]);
	NSData *fieldNorms = [reader norms: field];
	char *n = (char *)[fieldNorms bytes];
	float fieldNorm = (field != nil) ? [LCSimilarity decodeNorm: n[doc]] : 0.0f;
	[fieldNormExpl setValue: fieldNorm];
	[fieldNormExpl setRepresentation: [NSString stringWithFormat: @"fieldNorm(field=%@, doc=%d)", field, doc]];
	[fieldExpl addDetail: fieldNormExpl];
	
	[fieldExpl setValue: [tfExpl value]+[idfExpl value]+[fieldNormExpl value]];
	[result addDetail: fieldExpl];
	
	// combine them
	[result setValue: [queryExpl value]*[fieldExpl value]];
	if ([queryExpl value] == 1.0f)
		return fieldExpl;
	
	return AUTORELEASE(result);
}

@end
