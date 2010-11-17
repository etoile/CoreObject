#include "LCSimpleAnalyzer.h"
#include "LCLowerCaseTokenizer.h"
#include "GNUstep.h"

@implementation LCSimpleAnalyzer

/** An Analyzer that filters LetterTokenizer with LowerCaseFilter. */
- (LCTokenStream *) tokenStreamWithField: (NSString *) name
								  reader: (id <LCReader>) reader
{
	LCLowerCaseTokenizer *tokenizer = [[LCLowerCaseTokenizer alloc] initWithReader: reader];
	return AUTORELEASE(tokenizer); 
}

@end
