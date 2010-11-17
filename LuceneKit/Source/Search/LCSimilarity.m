#include "LCSimilarity.h"
#include "LCDefaultSimilarity.h"
#include "LCSearcher.h"
#include "LCSmallFloat.h"
#include "GNUstep.h"

static float *NORM_TABLE = NULL;
static LCSimilarity *defaultImpl = nil;

@implementation LCSimilarity

+ (void) setDefaultSimilarity: (LCSimilarity *) d
{
	ASSIGN(defaultImpl, d);
}

+ (LCSimilarity *) defaultSimilarity
{
	if (defaultImpl == nil)
	{
		ASSIGN(defaultImpl, AUTORELEASE([[LCDefaultSimilarity alloc] init]));
	}
	return defaultImpl;
}

/** Cache of decoded bytes. */
- (id) init
{
	self = [super init];
	if (NORM_TABLE == NULL)
    {
		NORM_TABLE = calloc(sizeof(float), 256);
		int i;
		for(i = 0; i < 256; i++)
			NORM_TABLE[i] = [LCSmallFloat byte315ToFloat: (char)i];
    }
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

/** Decodes a normalization factor stored in an index.
*  @see #encodeNorm(float)
*/
+ (float) decodeNorm: (char) b
{
	return NORM_TABLE[b & 0xff]; // & 0xFF maps negative bytes to positive above 127
}

/** Returns a table for decoding normalization bytes.
* @see #encodeNorm(float)
*/
+ (float *) normDecoder
{
	return NORM_TABLE;
}

/** Computes the normalization value for a field given the total number of
* terms contained in a field.  These values, together with field boosts, are
* stored in an index and multipled into scores for hits on each field by the
* search code.
*
* <p>Matches in longer fields are less precise, so implementations of this
* method usually return smaller values when <code>numTokens</code> is large,
* and larger values when <code>numTokens</code> is small.
*
* <p>That these values are computed under {@link
	* IndexWriter#addDocument(org.apache.lucene.document.Document)} and stored then using
* {@link #encodeNorm(float)}.  Thus they have limited precision, and documents
* must be re-indexed if this method is altered.
*
* @param fieldName the name of the field
* @param numTokens the total number of tokens contained in fields named
* <i>fieldName</i> of <i>doc</i>.
* @return a normalization factor for hits on this field of this document
*
* @see Field#setBoost(float)
*/
- (float) lengthNorm: (NSString *) fieldName numberOfTerms: (int) numTokens
{
	return -1;
}

/** Computes the normalization value for a query given the sum of the squared
* weights of each of the query terms.  This value is then multipled into the
* weight of each query term.
*
* <p>This does not affect ranking, but rather just attempts to make scores
* from different queries comparable.
*
* @param sumOfSquaredWeights the sum of the squares of query term weights
* @return a normalization factor for query weights
*/
- (float) queryNorm: (float) sumOfSquredWeights
{
	return -1;
}

/** Encodes a normalization factor for storage in an index.
*
* <p>The encoding uses a five-bit exponent and three-bit mantissa, thus
* representing values from around 7x10^9 to 2x10^-9 with about one
* significant decimal digit of accuracy.  Zero is also represented.
* Negative numbers are rounded up to zero.  Values too large to represent
* are rounded down to the largest representable value.  Positive values too
* small to represent are rounded up to the smallest positive representable
* value.
*
* @see Field#setBoost(float)
*/
+ (char) encodeNorm: (float) f
{
	return [LCSmallFloat floatToByte315: f];
}

/** Computes a score factor based on a term or phrase's frequency in a
* document.  This value is multiplied by the {@link #idf(Term, Searcher)}
* factor for each term in the query and these products are then summed to
* form the initial score for a document.
*
* <p>Terms and phrases repeated in a document indicate the topic of the
* document, so implementations of this method usually return larger values
* when <code>freq</code> is large, and smaller values when <code>freq</code>
* is small.
*
* <p>The default implementation calls {@link #tf(float)}.
*
* @param freq the frequency of a term within a document
* @return a score factor based on a term's within-document frequency
*/
- (float) termFrequencyWithInt: (int) freq
{
	return [self termFrequencyWithFloat: (float)freq];
}

/** Computes the amount of a sloppy phrase match, based on an edit distance.
* This value is summed for each sloppy phrase match in a document to form
* the frequency that is passed to {@link #tf(float)}.
*
* <p>A phrase match with a small edit distance to a document passage more
* closely matches the document, so implementations of this method usually
* return larger values when the edit distance is small and smaller values
* when it is large.
*
* @see PhraseQuery#setSlop(int)
* @param distance the edit distance of this sloppy phrase match
* @return the frequency increment for this match
*                                     */
- (float) sloppyFrequency: (int) distance
{
	return -1;
}

/** Computes a score factor based on a term or phrase's frequency in a
* document.  This value is multiplied by the {@link #idf(Term, Searcher)}
* factor for each term in the query and these products are then summed to
* form the initial score for a document.
*
* <p>Terms and phrases repeated in a document indicate the topic of the
* document, so implementations of this method usually return larger values
* when <code>freq</code> is large, and smaller values when <code>freq</code>
* is small.
*
* @param freq the frequency of a term within a document
* @return a score factor based on a term's within-document frequency
*/
- (float) termFrequencyWithFloat: (float) freq
{
	return -1;
}

/** Computes a score factor for a simple term.
*
* <p>The default implementation is:<pre>
*   return idf(searcher.docFreq(term), searcher.maxDoc());
* </pre>
*
* Note that {@link Searcher#maxDoc()} is used instead of
* {@link IndexReader#numDocs()} because it is proportional to
* {@link Searcher#docFreq(Term)} , i.e., when one is inaccurate,
* so is the other, and in the same direction.
*
* @param term the term in question
* @param searcher the document collection being searched
* @return a score factor for the term
*/
- (float) inverseDocumentFrequencyWithTerm: (LCTerm *) term
								  searcher: (LCSearcher *) searcher
{
	return [self inverseDocumentFrequency: [searcher documentFrequencyWithTerm: term]
						numberOfDocuments: [searcher maximalDocument]];
}

/** Computes a score factor for a phrase.
*
* <p>The default implementation sums the {@link #idf(Term,Searcher)} factor
* for each term in the phrase.
*
* @param terms the terms in the phrase
* @param searcher the document collection being searched
* @return a score factor for the phrase
*/
- (float) inverseDocumentFrequencyWithTerms: (NSArray *) terms
								   searcher: (LCSearcher *) searcher
{
	float idf = 0.0f;
	NSEnumerator *e = [terms objectEnumerator];
	LCTerm *t;
	while ((t = [e nextObject]))
	{
		idf += [self inverseDocumentFrequencyWithTerm: t searcher: searcher];
	}
	return idf;
}

/** Computes a score factor based on a term's document frequency (the number
* of documents which contain the term).  This value is multiplied by the
* {@link #tf(int)} factor for each term in the query and these products are
* then summed to form the initial score for a document.
*
* <p>Terms that occur in fewer documents are better indicators of topic, so
* implementations of this method usually return larger values for rare terms,
* and smaller values for common terms.
*
* @param docFreq the number of documents which contain the term
* @param numDocs the total number of documents in the collection
* @return a score factor based on the term's document frequency
*/
- (float) inverseDocumentFrequency: (int) docFreq 
				 numberOfDocuments: (int) numDocs
{
	return 0;
}

/** Computes a score factor based on the fraction of all query terms that a
* document contains.  This value is multiplied into scores.
*
* <p>The presence of a large portion of the query terms indicates a better
* match with the query, so implementations of this method usually return
* larger values when the ratio between these parameters is large and smaller
* values when the ratio between them is small.
*
* @param overlap the number of query terms matched in the document
* @param maxOverlap the total number of terms in the query
* @return a score factor based on term overlap with the query
*/
- (float) coordination: (int) overlap max: (int) maxOverlap
{
	return 0;
}

@end
