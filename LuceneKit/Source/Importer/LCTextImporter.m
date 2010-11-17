#include "LCTextImporter.h"
#include "LCDateTools.h"
#include "LCMetadataAttribute.h"

@implementation LCTextImporter
- (BOOL) metadataForFile: (NSString *) path type: (NSString *) type 
			  attributes: (NSMutableDictionary *) attributes
{
	if ([[self types] containsObject: type] == NO) return NO;
	[attributes setObject: path forKey: LCPathAttribute];
	[attributes setObject: [NSString stringWithContentsOfFile: path]
				   forKey: LCTextContentAttribute];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *attribs = [manager fileAttributesAtPath: path traverseLink: YES];
	NSDate *modificationDate = [attribs objectForKey: NSFileModificationDate];
	if ([modificationDate isEqualToDate: [attributes objectForKey: LCContentModificationDateAttribute]] == NO)
	{
		[attributes setObject: [NSString stringWithCalendarDate: [modificationDate dateWithCalendarFormat: nil timeZone: nil] resolution: LCResolution_SECOND]
					   forKey: LCContentModificationDateAttribute];
		[attributes setObject: [NSString stringWithCalendarDate: [NSCalendarDate date] resolution: LCResolution_SECOND]
					   forKey: LCMetadataChangeDateAttribute];
		return YES;
	}
	else
		return NO;
}

- (NSArray *) types
{
	return [NSArray arrayWithObjects: @"txt", @"text", nil];
}

- (NSString *) identifier
{
	return LCPathAttribute;
}

@end
