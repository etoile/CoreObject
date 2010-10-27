/*
	Copyright (C) 2010 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  January 2010
	License: Modified BSD (see COPYING)
 */

#import "ETByteSizeFormatter.h"
#import "Macros.h"
#import "EtoileCompatibility.h"
#include <math.h>

@implementation ETByteSizeFormatter

/** Converts the given byte size (must be a NSNumber object) into a 
human-readable string expressed in:
<deflist>
<term>B</term><desc>bytes</desc>
<term>KB</term><desc>kilobytes</desc>
<term>MB</term><desc>megabytes</desc>
<term>GB</term><desc>gigabytes</desc>
<term>TB</term><desc>terabytes</desc>
</deflist>.

No digits are displayed after the decimal point for B and KB, one digit for 
MB, two digits for GB and three digits for TB. */
- (NSString *) stringForObjectValue: (id)anObject
{
	NSParameterAssert([anObject isKindOfClass: [NSNumber class]]);

	NSArray *sizeUnits = A(_(@"B"), _(@"KB"), _(@"MB"), _(@"GB"), _(@"TB"));
	int nbOfUnits = [sizeUnits count];
	float value = [anObject floatValue];
  	int unitLevel = 0;

	while (value >= 1024 && unitLevel < nbOfUnits)
	{
		value = value / 1024;
		unitLevel++;		
	}
  
	// TODO: Support full format localization. 
	// e.g. 10.2 MB vs 10,2 Mo on a French system.
	NSString *format = @"%.0f %@";
	NSString *unit = [sizeUnits objectAtIndex: unitLevel];
	BOOL isMBSizeOrGreater = (unitLevel >= 2);

	if (isMBSizeOrGreater)
	{
		format = [@"%." stringByAppendingString: [NSString stringWithFormat: @"%i", unitLevel - 1]];
		format = [format stringByAppendingString: @"f %@"];
	}

	return [NSString localizedStringWithFormat: format, value, unit];
}

@end

