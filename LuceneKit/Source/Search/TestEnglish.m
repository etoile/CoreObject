#include "TestEnglish.h"
#include "GNUstep.h"

@implementation TestEnglish

#if 0
- (void) testEnglish
{
	NSLog(@"%@", [TestEnglish intToEnglish: 86453184]);
}
#endif

+ (NSString *) intToEnglish: (int) j
{
	int i = j;
	NSMutableString *result = [[NSMutableString alloc] init];
	AUTORELEASE(result);
	
    if (i == 0) {
		return @"zero";
    }
    if (i < 0) {
		[result appendString: @"minus "];
		i = -i;
    }
    if (i >= 1000000000) {			  // billions
		[result appendString: [TestEnglish intToEnglish: i/1000000000]];
		[result appendString: @"billion, "];
		i = i%1000000000;
    }
    if (i >= 1000000) {				  // millions
		[result appendString: [TestEnglish intToEnglish: i/1000000]];
		[result appendString: @"million, "];
		i = i%1000000;
    }
    if (i >= 1000) {				  // thousands
		[result appendString: [TestEnglish intToEnglish: i/1000]];
		[result appendString: @"thousand, "];
		i = i%1000;
    }
    if (i >= 100) {				  // hundreds
		[result appendString: [TestEnglish intToEnglish: i/100]];
		[result appendString: @"hundred, "];
		i = i%100;
    }
    if (i >= 20) {
		switch (i/10) {
			case 9 : [result appendString: @"ninety"]; break;
			case 8 : [result appendString: @"eighty"]; break;
			case 7 : [result appendString: @"seventy"]; break;
			case 6 : [result appendString: @"sixty"]; break;
			case 5 : [result appendString: @"fifty"]; break;
			case 4 : [result appendString: @"forty"]; break;
			case 3 : [result appendString: @"thirty"]; break;
			case 2 : [result appendString: @"twenty"]; break;
		}
		i = i%10;
		if (i == 0)
			[result appendString: @" "];
		else 
			[result appendString: @"-"];
    }
    switch (i) {
		case 19 : [result appendString: @"nineteen "]; break;
		case 18 : [result appendString: @"eighteen "]; break;
		case 17 : [result appendString: @"seventeen "]; break;
		case 16 : [result appendString: @"sixteen "]; break;
		case 15 : [result appendString: @"fifteen "]; break;
		case 14 : [result appendString: @"fourteen "]; break;
		case 13 : [result appendString: @"thirteen "]; break;
		case 12 : [result appendString: @"twelve "]; break;
		case 11 : [result appendString: @"eleven "]; break;
		case 10 : [result appendString: @"ten "]; break;
		case 9 : [result appendString: @"nine "]; break;
		case 8 : [result appendString: @"eight "]; break;
		case 7 : [result appendString: @"seven "]; break;
		case 6 : [result appendString: @"six "]; break;
		case 5 : [result appendString: @"five "]; break;
		case 4 : [result appendString: @"four "]; break;
		case 3 : [result appendString: @"three "]; break;
		case 2 : [result appendString: @"two "]; break;
		case 1 : [result appendString: @"one "]; break;
		case 0 : [result appendString: @""]; break;
    }
	return AUTORELEASE([result copy]);
}

@end
