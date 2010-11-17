#include "LCFilterIndexReader.h"
#include "LCTerm.h"
#include "GNUstep.h"

/** Filter that only permits terms containing 'e'.*/
@interface TestTermEnum: LCFilterTermEnumerator
@end

@implementation TestTermEnum

/** Scan for terms containing the letter 'e'.*/
- (BOOL) hasNextTerm
{
	while ([input hasNextTerm])
	{
		if ([[[input term] text] rangeOfString: @"e"].location != NSNotFound)
			return YES;
	}
	return NO;
}

@end

/** Filter that only returns odd numbered documents. */
@interface TestTermPositions: LCFilterTermPositions
@end

@implementation TestTermPositions
- (BOOL) hasNextDocument
{
	while ([input hasNextDocument])
	{
		if (([input document] % 2) == 1)
			return YES;
	}
	return NO;
}
@end

@interface TestReader: LCFilterIndexReader
@end

@implementation TestReader
/** Filter terms with TestTermEnum. */
- (LCTermEnumerator *) termEnumerator
{
	return [[TestTermEnum alloc] initWithTermEnumerator: [input termEnumerator]];
}

/** Filter positions with TestTermPositions. */
- (id <LCTermPositions>) termPositions
{
	return [[TestTermPositions alloc] initWithTermPositions: [input termPositions]];
}
@end

#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCDocument.h"
#include "LCField.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>

@interface TestFilterIndexReader: NSObject <UKTest>
@end

@implementation TestFilterIndexReader 

/**
* Tests the IndexReader.getFieldNames implementation
 * @throws Exception on error
 */
- (void) testFilterIndexReader
{
	LCRAMDirectory *directory = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory
															analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	LCDocument *d1 = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"default"
											string: @"one two"
											 store: LCStore_YES
											 index: LCIndex_Tokenized];
	[d1 addField: field];
	DESTROY(field);
	[writer addDocument: d1];
	DESTROY(d1);
	
	LCDocument *d2 = [[LCDocument alloc] init];
	field = [[LCField alloc] initWithName: @"default"
								   string: @"one three"
									store: LCStore_YES
									index: LCIndex_Tokenized];
	[d2 addField: field];
	DESTROY(field);
	[writer addDocument: d2];
	DESTROY(d2);
	
	LCDocument *d3 = [[LCDocument alloc] init];
	field = [[LCField alloc] initWithName: @"default"
								   string: @"one four"
									store: LCStore_YES
									index: LCIndex_Tokenized];
	[d3 addField: field];
	DESTROY(field);
	[writer addDocument: d3];
	DESTROY(d3);
	[writer close];
	DESTROY(writer);
	
	LCIndexReader *r = [LCIndexReader openDirectory: directory];
	LCIndexReader *reader = [[TestReader alloc] initWithIndexReader: r];
	
	LCTermEnumerator *terms = [reader termEnumerator];
	while ([terms hasNextTerm]) {
		UKTrue([[[terms term] text] rangeOfString: @"e"].location != NSNotFound);
	}
	[terms close];
    
	LCTerm *term = [[LCTerm alloc] initWithField: @"default" text: @"one"];
	id <LCTermPositions> positions = [reader termPositionsWithTerm: term];
	while ([positions hasNextDocument] == YES) 
	{
		UKIntsEqual(([positions document] % 2), 1);
	}
	
	DESTROY(term);
	[reader close];
	DESTROY(reader);
}

@end
