#include "NSString+Additions.h"

@implementation NSString (LuceneKit_Util)
- (int) positionOfDifference: (NSString *) other
{
	int len1 = [self length];
	int len2 = [other length];
	int len = len1 < len2 ? len1 : len2;
	int i;
	for (i = 0; i < len; i++) 
    {
		if ([self characterAtIndex: i] != [other characterAtIndex: i ])
        {
			return i;
        }
    }
	return len;
}
@end

NSString *LCStringFromBoost(float boost)
{
	if (boost != 1.0f) {
		return [NSString stringWithFormat: @"^%f", boost];
	} else return [NSString stringWithString: @""];
}

