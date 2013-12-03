#import "UnorderedGroupNoOpposite.h"

@implementation UnorderedGroupNoOpposite

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
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnorderedGroupNoOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.COObject"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;

@end