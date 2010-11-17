#include "TestDocHelper.h"
#include "LCField.h"
#include "LCDocument.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCSimilarity.h"
#include "LCDocumentWriter.h"
#include "GNUstep.h"

static NSString *FIELD_1_TEXT;
static NSString *TEXT_FIELD_1_KEY;
static NSString *FIELD_2_TEXT;
static NSString *TEXT_FIELD_2_KEY;
static NSString *FIELD_3_TEXT;
static NSString *TEXT_FIELD_3_KEY;
static NSString *KEYWORD_TEXT;
static NSString *KEYWORD_FIELD_KEY;
static NSString *UNINDEXED_FIELD_TEXT;
static NSString *UNINDEXED_FIELD_KEY;
static NSString *UNSTORED_1_FIELD_TEXT;
static NSString *UNSTORED_2_FIELD_TEXT;
static NSString *UNSTORED_FIELD_1_KEY;
static NSString *UNSTORED_FIELD_2_KEY;
static NSString *NO_NORMS_TEXT;
static NSString *NO_NORMS_KEY;
static NSArray *FIELD_2_FREQS;

static NSMutableDictionary *all;
static NSMutableDictionary *indexed;
static NSMutableDictionary *stored;
static NSMutableDictionary *unstored;
static NSMutableDictionary *unindexed;
static NSMutableDictionary *termvector;
static NSMutableDictionary *notermvector;
static NSMutableDictionary *noNorms;

static NSArray *fields;

@implementation TestDocHelper
+ (NSString *) FIELD_1_TEXT
{
	return FIELD_1_TEXT;
}

+ (NSString *) TEXT_FIELD_1_KEY
{
	return TEXT_FIELD_1_KEY;
}

+ (NSString *) FIELD_2_TEXT
{
	return FIELD_2_TEXT;
}

+ (NSString *) TEXT_FIELD_2_KEY
{
	return TEXT_FIELD_2_KEY;
}

+ (NSString *) FIELD_3_TEXT
{
	return FIELD_3_TEXT;
}

+ (NSString *) TEXT_FIELD_3_KEY
{
	return TEXT_FIELD_3_KEY;
}

+ (NSString *) KEYWORD_TEXT 
{
	return KEYWORD_TEXT;
}

+ (NSString *) KEYWORD_FIELD_KEY
{
	return KEYWORD_FIELD_KEY;
}

+ (NSString *) UNINDEXED_FIELD_TEXT
{
	return UNINDEXED_FIELD_TEXT;
}

+ (NSString *) UNINDEXED_FIELD_KEY
{
	return UNINDEXED_FIELD_KEY;
}

+ (NSString *) UNSTORED_1_FIELD_TEXT
{
	return UNSTORED_1_FIELD_TEXT;
}

+ (NSString *) UNSTORED_2_FIELD_TEXT
{
	return UNSTORED_2_FIELD_TEXT;
}

+ (NSString *) UNSTORED_FIELD_1_KEY
{
	return UNSTORED_FIELD_1_KEY;
}

+ (NSString *) UNSTORED_FIELD_2_KEY
{
	return UNSTORED_FIELD_2_KEY;
}

+ (NSString *) NO_NORMS_TEXT 
{
	return NO_NORMS_TEXT;
}

+ (NSString *) NO_NORMS_KEY
{
	return NO_NORMS_KEY;
}

+ (NSArray *) FIELD_2_FREQS
{
	return FIELD_2_FREQS;
}

+ (NSDictionary *) all
{
	return all;
}

+ (NSDictionary *) indexed
{
	return indexed;
}

+ (NSDictionary *) stored
{
	return stored;
}

+ (NSDictionary *) unstored
{
	return unstored;
}

+ (NSDictionary *) unindexed
{
	return unindexed;
}

+ (NSDictionary *) termvector
{
	return termvector;
}

+ (NSDictionary *) notermvector
{
	return notermvector;
}

+ (NSDictionary *) noNorms
{
	return noNorms;
}

+ (NSArray *) fields
{
	return fields;
}

+ (void) setupDoc: (LCDocument *) doc
{
	FIELD_1_TEXT = @"field one text";
	TEXT_FIELD_1_KEY = @"textField1";
	LCField *textField1 = [[LCField alloc] initWithName: TEXT_FIELD_1_KEY
												 string: FIELD_1_TEXT
												  store: LCStore_YES
												  index: LCIndex_Tokenized
											 termVector: LCTermVector_NO];
	
	FIELD_2_TEXT = @"field field field two text";
	//Fields will be lexicographically sorted.  So, the order is: field, text, two
	FIELD_2_FREQS = [[NSArray alloc] initWithObjects: [NSNumber numberWithInt: 3],
		[NSNumber numberWithInt: 1], 
		[NSNumber numberWithInt: 1], nil]; 
	TEXT_FIELD_2_KEY = @"textField2";
	LCField *textField2 = [[LCField alloc] initWithName: TEXT_FIELD_2_KEY
												 string: FIELD_2_TEXT
												  store: LCStore_YES
												  index: LCIndex_Tokenized
											 termVector: LCTermVector_WithPositionsAndOffsets];
	
	FIELD_3_TEXT = @"aaaNoNorms aaaNoNorms bbbNoNorms";
	TEXT_FIELD_3_KEY = @"textField3";
	LCField *textField3 = [[LCField alloc] initWithName: TEXT_FIELD_3_KEY
												 string: FIELD_3_TEXT
												  store: LCStore_YES
												  index: LCIndex_Tokenized];
	[textField3 setOmitNorms: YES];

	KEYWORD_TEXT = @"Keyword";
	KEYWORD_FIELD_KEY = @"keyField";
	LCField *keyField = [[LCField alloc] initWithName: KEYWORD_FIELD_KEY 
											   string: KEYWORD_TEXT
												store: LCStore_YES
												index: LCIndex_Untokenized];
	
	NO_NORMS_TEXT = @"omitNormsText";
	NO_NORMS_KEY = @"omitNorms";
	LCField *noNormsField = [[LCField alloc] initWithName: NO_NORMS_KEY 
											   string: NO_NORMS_TEXT
												store: LCStore_YES
												index: LCIndex_NoNorms];
	
	UNINDEXED_FIELD_TEXT = @"unindexed field text";
	UNINDEXED_FIELD_KEY = @"unIndField";
	LCField *unIndField = [[LCField alloc] initWithName: UNINDEXED_FIELD_KEY
												 string: UNINDEXED_FIELD_TEXT
												  store: LCStore_YES
												  index: LCIndex_NO];
	
	UNSTORED_1_FIELD_TEXT = @"unstored field text";
	UNSTORED_FIELD_1_KEY = @"unStoredField1";
	LCField *unStoredField1 = [[LCField alloc] initWithName: UNSTORED_FIELD_1_KEY
													 string: UNSTORED_1_FIELD_TEXT
													  store: LCStore_NO
													  index: LCIndex_Tokenized
												 termVector: LCTermVector_NO];
	
	UNSTORED_2_FIELD_TEXT = @"unstored field text";
	UNSTORED_FIELD_2_KEY = @"unStoredField2";
	LCField *unStoredField2 = [[LCField alloc] initWithName: UNSTORED_FIELD_2_KEY
													 string: UNSTORED_2_FIELD_TEXT
													  store: LCStore_NO
													  index: LCIndex_Tokenized
												 termVector: LCTermVector_YES];

	fields = [[NSArray alloc] initWithObjects:
				textField1, textField2, textField3,
				keyField, noNormsField, unIndField,
				unStoredField1, unStoredField2, nil];

	all = [[NSMutableDictionary alloc] init];
	indexed = [[NSMutableDictionary alloc] init];
	stored = [[NSMutableDictionary alloc] init];
	unstored = [[NSMutableDictionary alloc] init];
	unindexed = [[NSMutableDictionary alloc] init];
	termvector = [[NSMutableDictionary alloc] init];
	notermvector = [[NSMutableDictionary alloc] init];
	noNorms = [[NSMutableDictionary alloc] init];

	int j;
	for (j = 0; j < [fields count]; j++)
	{
		LCField *f = [fields objectAtIndex: j];
		[all setObject: f forKey: [f name]]; 
		if ([f isIndexed]) 
			[indexed setObject: f forKey: [f name]]; 
		else
			[unindexed setObject: f forKey: [f name]]; 
		if ([f isTermVectorStored]) 
			[termvector setObject: f forKey: [f name]]; 
		if ([f isIndexed] && (![f isTermVectorStored]))
			[notermvector setObject: f forKey: [f name]]; 
		if ([f isStored])
			[stored setObject: f forKey: [f name]];
		else
			[unstored setObject: f forKey: [f name]];
		if ([f omitNorms])
			[noNorms setObject: f forKey: [f name]];
	}
		


#if 0 // Not sure what does this do
  	 
  	   static {
  	     for (int i=0; i<fields.length; i++) {
  	       Field f = fields[i];
  	       add(all,f);
  	       if (f.isIndexed()) add(indexed,f);
  	       else add(unindexed,f);
  	       if (f.isTermVectorStored()) add(termvector,f);
  	       if (f.isIndexed() && !f.isTermVectorStored()) add(notermvector,f);
  	       if (f.isStored()) add(stored,f);
  	       else add(unstored,f);
  	       if (f.getOmitNorms()) add(noNorms,f);
  	     }
  	   }
  	 
  	 
  	   private static void add(Map map, Field field) {
  	     map.put(field.name(), field);
  	   }
  	 
#endif

	int i;
	for (i = 0; i < [fields count]; i++) {
		[doc addField: [fields objectAtIndex: i]];
	}
}                         

+ (NSDictionary *) nameValues
{
	NSDictionary *nameValues = [[NSDictionary alloc] initWithObjectsAndKeys:
		FIELD_1_TEXT, TEXT_FIELD_1_KEY,
		FIELD_2_TEXT, TEXT_FIELD_2_KEY,
		FIELD_3_TEXT, TEXT_FIELD_3_KEY,
		KEYWORD_TEXT, KEYWORD_FIELD_KEY,
		UNINDEXED_FIELD_TEXT, UNINDEXED_FIELD_KEY,
		NO_NORMS_TEXT, NO_NORMS_KEY,
		UNSTORED_1_FIELD_TEXT, UNSTORED_FIELD_1_KEY, 
		UNSTORED_2_FIELD_TEXT, UNSTORED_FIELD_2_KEY, nil];
    return AUTORELEASE(nameValues);
}

/**
* Writes the document to the directory using a segment named "test"
 * @param dir
 * @param doc
 */ 
+ (void) writeDirectory: (id <LCDirectory>) dir doc: (LCDocument *) doc
{
	[TestDocHelper writeDirectory: dir segment: @"test" doc: doc];
}

/**
* Writes the document to the directory in the given segment
 * @param dir
 * @param segment
 * @param doc
 */ 
+ (void) writeDirectory: (id <LCDirectory>) dir segment: (NSString *) segment              doc: (LCDocument *) doc
{
	LCAnalyzer *analyzer = [[LCWhitespaceAnalyzer alloc] init];
	LCSimilarity *similarity = [LCSimilarity defaultSimilarity];
	[TestDocHelper writeDirectory: dir
						 analyzer: analyzer
					   similarity: similarity
						  segment: segment
							  doc: doc];
}

/**
* Writes the document to the directory segment named "test" using the specified analyzer and similarity
 * @param dir
 * @param analyzer
 * @param similarity
 * @param doc
 */ 
+ (void) writeDirectory: (id <LCDirectory>) dir 
			   analyzer: (LCAnalyzer *) analyzer
			 similarity: (LCSimilarity *) similarity doc: (LCDocument *) doc
{
	[TestDocHelper writeDirectory: dir
						 analyzer: analyzer
					   similarity: similarity
						  segment: @"test" 
							  doc: doc];
}

/**
* Writes the document to the directory segment using the analyzer and the similarity score
 * @param dir
 * @param analyzer
 * @param similarity
 * @param segment
 * @param doc
 */ 
+ (void) writeDirectory: (id <LCDirectory>) dir 
			   analyzer: (LCAnalyzer *) analyzer
			 similarity: (LCSimilarity *) similarity
				segment: (NSString *) segment doc: (LCDocument *) doc
{
	LCDocumentWriter *writer = [[LCDocumentWriter alloc]
	  initWithDirectory: dir
			   analyzer: analyzer
			 similarity: similarity
		 maxFieldLength: 50];
	[writer addDocument: segment document: doc];
}

+ (int) numFields: (LCDocument *) doc  
{
	NSEnumerator *e = [doc fieldEnumerator];
	int result = 0;
    while ([e nextObject])
    {
		result++;
    }
    return result;
}

@end
