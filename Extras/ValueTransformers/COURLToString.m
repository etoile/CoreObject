/*
	Copyright (C) 2015 Quentin Mathe

	Date:  July 2015
	License:  MIT  (see COPYING)
 */

#import "COURLToString.h"

@implementation COURLToString

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
	if (value == nil)
		return nil;

	NSParameterAssert([value isKindOfClass: [NSURL class]]);

	return ((NSURL *)value).absoluteString;
}

- (id)reverseTransformedValue: (id)value
{
	if (value == nil)
		return nil;

	NSParameterAssert([value isKindOfClass: [NSString class]]);

	return [NSURL URLWithString: (NSString *)value];
}

@end
