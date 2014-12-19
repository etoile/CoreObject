/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "UnivaluedGroupNoOpposite.h"

@implementation UnivaluedGroupNoOpposite

static NSUInteger DeallocCalls;

+ (NSUInteger) countOfDeallocCalls
{
	return DeallocCalls;
}

- (void) dealloc
{
	DeallocCalls++;
}

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [UnivaluedGroupNoOpposite className]])
		return entity;
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentProperty = [ETPropertyDescription descriptionWithName: @"content"
																				   type: (id)@"Anonymous.COObject"];
    [contentProperty setPersistent: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, contentProperty]];
	
    return entity;
}

@dynamic label;
@dynamic content;

@end
