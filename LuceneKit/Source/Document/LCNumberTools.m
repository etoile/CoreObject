#include "LCNumberTools.h"
#include <limits.h>

char _dig_vec[] =
"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

//long long MAX_LONG = (((unsigned long long)(-1)) / 2) - 1; // MAX of long

//#define STR_SIZE 13

@implementation NSString (LuceneKit_Document_Number)

+ (NSString *) stringWithLongLong: (long long) v
{
	return [NSString stringWithFormat: @"%lld", v];
}

/**
* Converts a String that was returned by {@link #longToString} back to a
 * long.
 * 
 * @throws IllegalArgumentException
 *             if the input is null
 * @throws NumberFormatException
 *             if the input does not parse (it was not a String returned by
											*             longToString()).
 */
- (long long) longLongValue
{  
	char *p = (char *)[self cString];
	long long val, new_val = 0LL;
	int minus = 1;
	if (*p++ == '-')
    {
		minus = -1;
    }
	
	while((*p != 0))
    {
		if (*p < 'A') 
        {
			val = *p-'0';
        }
		else if (*p < 'a')
        {
			val = *p-'A'+10;
        }
		else
        {
			val = *p-'a'+10;
        }
		
		new_val = new_val*RADIX+val;
		p++;
    }
	
	if (minus == -1)
    {
		new_val = new_val - LLONG_MAX -1;
		return new_val;
    }
	else
		return new_val;
}

@end
