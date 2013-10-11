/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COTag.h"
#import "COPersistentRoot.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COTag

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTag className]] == NO) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTag"
	                               description: @"Core Object Tag"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag")];

	ETPropertyDescription *contentProperty = 
		[self contentPropertyDescriptionWithName: @"objects" type: @"COObject" opposite: @"COObject.tags"];
	ETPropertyDescription *tagGroupsProperty =
		[ETPropertyDescription descriptionWithName: @"tagGroups" type: (id)@"COTagGroup"];
	[tagGroupsProperty setMultivalued: YES];
	[tagGroupsProperty setOpposite: (id)@"COTagGroup.contents"];

	[collection setPropertyDescriptions: A(contentProperty, tagGroupsProperty)];

	return collection;
}

- (NSString *)contentKey
{
	return @"objects";
}

- (BOOL)isTag
{
	assert([[[[self persistentRoot] parentContext] tagLibrary] containsObject: self]);
	return YES;
}

- (NSString *)tagString
{
	return [[self name] lowercaseString];
}

- (NSSet *)tagGroups
{
	return [self primitiveValueForKey: @"tagGroups"];
}

@end


@implementation COTagGroup

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTagGroup className]] == NO) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTagGroup"
	                               description: @"Core Object Tag Group"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag Group")];

	ETPropertyDescription *contentProperty = 
		[self contentPropertyDescriptionWithName: @"contents" type: @"COTag" opposite: @"COTag.tagGroups"];

	[collection setPropertyDescriptions: A(contentProperty)];

	return collection;
}

@end


@implementation COTagLibrary

@synthesize tagGroups = _tagGroups;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add the
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTagLibrary className]] == NO)
		return collection;

	 ETPropertyDescription *tagGroups =
		[ETPropertyDescription descriptionWithName: @"tagGroups" type: (id)@"COTagGroup"];
	[tagGroups setMultivalued: YES];
	[tagGroups setOrdered: YES];
	[tagGroups setPersistent: YES];
	ETPropertyDescription *content =
		[self contentPropertyDescriptionWithName: @"contents" type: (id)@"COTag" opposite: nil];

	[collection setPropertyDescriptions: A(tagGroups, content)];
	
	return collection;
}

- (id)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	[self setIdentifier: kCOLibraryIdentifierTag];
	[self setName: _(@"Tags")];
	_tagGroups = [[NSMutableArray alloc] init];
	return self;
}

@end
