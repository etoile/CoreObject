#include "LCAnalyzer.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>
#include "LCStringReader.h"

@implementation LCAnalyzer (UKTest_Additions)

- (void) compare: (NSString *) s and: (NSArray *) a 
            with: (LCAnalyzer *) analyzer
{
	LCStringReader *reader = [[LCStringReader alloc] initWithString: s];
	LCTokenStream *stream = [analyzer tokenStreamWithField: @"contents"
													reader: reader];
	int i = 0;
	LCToken *token;
	while((token = [stream nextToken]))
    {
		UKStringsEqual([a objectAtIndex: i++], [token termText]);
    }
	
	RELEASE(reader);
}
@end
