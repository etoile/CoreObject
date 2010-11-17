#ifndef __LUCENE_INDEX_TEST_DOC_HELPER__
#define __LUCENE_INDEX_TEST_DOC_HELPER__

#include <Foundation/Foundation.h>
#include "LCDirectory.h"

@class LCField;
@class LCDocument;
@class LCSimilarity;
@class LCAnalyzer;

@interface TestDocHelper: NSObject
+ (void) setupDoc: (LCDocument *) doc;
+ (void) writeDirectory: (id <LCDirectory>) dir doc: (LCDocument *) doc;
+ (void) writeDirectory: (id <LCDirectory>) dir segment: (NSString *) segment
					doc: (LCDocument *) doc;
+ (void) writeDirectory: (id <LCDirectory>) dir 
			   analyzer: (LCAnalyzer *) analyzer
			 similarity: (LCSimilarity *) similarity doc: (LCDocument *) doc;
+ (void) writeDirectory: (id <LCDirectory>) dir 
			   analyzer: (LCAnalyzer *) analyzer
			 similarity: (LCSimilarity *) similarity
				segment: (NSString *) segment doc: (LCDocument *) doc;
+ (int) numFields: (LCDocument *) doc;
+ (NSDictionary *) nameValues;

+ (NSString *) FIELD_1_TEXT;
+ (NSString *) TEXT_FIELD_1_KEY;
+ (NSString *) FIELD_2_TEXT;
+ (NSString *) TEXT_FIELD_2_KEY;
+ (NSString *) FIELD_3_TEXT;
+ (NSString *) TEXT_FIELD_3_KEY;
+ (NSString *) KEYWORD_TEXT;
+ (NSString *) KEYWORD_FIELD_KEY;
+ (NSString *) NO_NORMS_TEXT;
+ (NSString *) NO_NORMS_KEY;
+ (NSString *) UNINDEXED_FIELD_TEXT;
+ (NSString *) UNINDEXED_FIELD_KEY;
+ (NSString *) UNSTORED_1_FIELD_TEXT;
+ (NSString *) UNSTORED_2_FIELD_TEXT;
+ (NSString *) UNSTORED_FIELD_1_KEY;
+ (NSString *) UNSTORED_FIELD_2_KEY;
+ (NSArray *) FIELD_2_FREQS;

+ (NSDictionary *) all;
+ (NSDictionary *) indexed;
+ (NSDictionary *) stored;
+ (NSDictionary *) unstored;
+ (NSDictionary *) unindexed;
+ (NSDictionary *) termvector;
+ (NSDictionary *) notermvector;
+ (NSDictionary *) noNorms;

+ (NSArray *) fields;

@end
#endif /* __LUCENE_INDEX_TEST_DOC_HELPER__ */
