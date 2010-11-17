#include "LCAnalyzer.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>
#include "LCStringReader.h"

@interface LCAnalyzer (UKTest_Additions)
- (void) compare: (NSString *) s and: (NSArray *) a
            with: (LCAnalyzer *) analyzer;
@end

