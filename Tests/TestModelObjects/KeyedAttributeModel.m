#import "KeyedAttributeModel.h"

@implementation KeyedAttributeModel

@dynamic entries;

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [KeyedAttributeModel className]] == NO)
		return object;
	
	ETPropertyDescription *entries =
	[ETPropertyDescription descriptionWithName: @"entries" type: (id)@"NSString"];
	[entries setMultivalued: YES];
	[entries setKeyed: YES];
	[entries setPersistent: YES];
	
	[object addPropertyDescription: entries];
	
	return object;
}

@end
