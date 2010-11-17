#include "LCWhitespaceAnalyzer.h"
#include "LCWhitespaceTokenizer.h"
#include "GNUstep.h"

@implementation LCWhitespaceAnalyzer

- (LCTokenStream *) tokenStreamWithField: (NSString *) name
								  reader: (id <LCReader>) reader
{
	return AUTORELEASE([[LCWhitespaceTokenizer alloc] initWithReader: reader]);
}

@end
