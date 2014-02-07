/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "TypewriterDocument.h"

@implementation TypewriterDocument

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"TypewriterDocument"];
    [entity setParent: (id)@"COObject"];
    
    ETPropertyDescription *attrString = [ETPropertyDescription descriptionWithName: @"attrString"
																			  type: (id)@"COAttributedString"];
    [attrString setPersistent: YES];
    [entity setPropertyDescriptions: @[attrString]];
    return entity;
}

- (instancetype) initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	self.attrString = [[COAttributedString alloc] initWithObjectGraphContext: aContext];
	return self;
}

@dynamic attrString;

@end
