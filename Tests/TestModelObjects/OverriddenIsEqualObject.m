/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  January 2014
	License:  MIT  (see COPYING)
 */

#import "OverriddenIsEqualObject.h"

@implementation OverriddenIsEqualObject

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"OverriddenIsEqualObject"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	[entity setPropertyDescriptions: @[labelProperty]];
	
    return entity;
}

@dynamic label;

- (NSUInteger) hash
{
	return [self.label hash];
}

- (BOOL) isEqual:(id)anObject
{
	if (![anObject isKindOfClass: [OverriddenIsEqualObject class]])
		return NO;
	return [[anObject label] isEqualToString: self.label];
}

@end

