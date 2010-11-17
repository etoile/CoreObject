#include "LCQuery.h"

@interface LCPrefixQuery: LCQuery
{
	LCTerm *prefix;
}

- (id) initWithTerm: (LCTerm *) prefix;
- (LCTerm *) prefix;
@end

