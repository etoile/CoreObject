/*
	Copyright (C) 2014 Quentin Mathe

	Date:  May 2014
	License:  MIT  (see COPYING)
 */

#import "COObjectToArchivedData.h"

@implementation COObjectToArchivedData

+ (Class)transformedValueClass
{
	return [NSData class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue: (id)value
{
	return (value != nil ? [NSKeyedArchiver archivedDataWithRootObject: value] : nil);
}

- (id)reverseTransformedValue: (id)value
{
	NSParameterAssert(value == nil || [value isKindOfClass: [NSData class]]);

	return (value != nil ? [NSKeyedUnarchiver unarchiveObjectWithData: value] : nil);
}

@end
