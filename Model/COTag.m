/*
	Copyright (C) 2013 Quentin Mathe

	Date:  March 2013
	License:  MIT  (see COPYING)
 */

#import "COTag.h"
#import "COPersistentRoot.h"

@implementation COTag

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if (![collection.name isEqual: [COTag className]]) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTag"
	                               description: @"Core Object Tag"
	                          supertypeStrings: @[]
	                                  typeTags: @{}];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag")];

	ETPropertyDescription *objects =
		[self contentPropertyDescriptionWithName: @"objects"
		                                    type: @"COObject"
		                                opposite: @"COObject.tags"];
	ETPropertyDescription *tagGroups =
		[ETPropertyDescription descriptionWithName: @"tagGroups" type: (id)@"COTagGroup"];
	[tagGroups setMultivalued: YES];
	tagGroups.opposite = (id)@"COTagGroup.objects";
	[tagGroups setDerived: YES];

	[collection setPropertyDescriptions: A(objects, tagGroups)];

	return collection;
}

- (BOOL)isTag
{
	// FIXME: I just commented out this assertion which looks wrong to me,.. do we really want to forbit using tags in
	// a freestanding COObjectGraphContext, or just not registered with a tag library? -Eric
	//
	//assert([self.persistentRoot.parentContext.tagLibrary containsObject: self]);
	return YES;
}

- (NSString *)tagString
{
	return self.name.lowercaseString;
}

- (NSSet *)tagGroups
{
	return [self valueForVariableStorageKey: @"tagGroups"];
}

@end


@implementation COTagGroup

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if (![collection.name isEqual: [COTagGroup className]]) 
		return collection;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COTagGroup"
	                               description: @"Core Object Tag Group"
	                          supertypeStrings: @[]
	                                  typeTags: @{}];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[collection setLocalizedDescription: _(@"Tag Group")];

	ETPropertyDescription *objects =
		[self contentPropertyDescriptionWithName: @"objects"
		                                    type: @"COTag"
		                                opposite: @"COTag.tagGroups"];

	[collection setPropertyDescriptions: A(objects)];

	return collection;
}

@end


@implementation COTagLibrary

@dynamic tagGroups;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add the
	// property descriptions that we will inherit through the parent
	if (![collection.name isEqual: [COTagLibrary className]])
		return collection;

	 ETPropertyDescription *tagGroups =
		[ETPropertyDescription descriptionWithName: @"tagGroups" type: (id)@"COTagGroup"];
	[tagGroups setMultivalued: YES];
	[tagGroups setOrdered: YES];
	[tagGroups setPersistent: YES];
	ETPropertyDescription *objects =
		[self contentPropertyDescriptionWithName: @"objects"
		                                    type: (id)@"COTag"
		                                opposite: nil];

	[collection setPropertyDescriptions: A(tagGroups, objects)];
	
	return collection;
}

- (instancetype)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	self.identifier = kCOLibraryIdentifierTag;
	[self setName: _(@"Tags")];
	return self;
}

@end
