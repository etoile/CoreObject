#import "CORectToString.h"

@implementation CORectToString

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue: (id)value
{
	ETAssert([value isKindOfClass: [NSValue class]]);
	NSValue *nsvalue = value;

	return NSStringFromRect([nsvalue rectValue]);
}

- (id)reverseTransformedValue: (id)value
{
	ETAssert([value isKindOfClass: [NSString class]]);
	NSString *string = value;
	
	return [NSValue valueWithRect: NSRectFromString(string)];
}

@end
