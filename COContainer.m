/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COContainer.h"
#import "COGroup.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COContainer

+ (ETPropertyDescription *)contentPropertyDescriptionWithName: (NSString *)aName
                                                         type: (NSString *)aType
                                                     opposite: (NSString *)oppositeType
{
	ETPropertyDescription *contentProperty = 
		[ETPropertyDescription descriptionWithName: aName type: (id)aType];
	[contentProperty setMultivalued: YES];
	[contentProperty setOpposite: (id)oppositeType];
	[contentProperty setOrdered: YES];
	[contentProperty setPersistent: YES];
	return contentProperty;
}

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COContainer className]] == NO) 
		return collection;
	
	ETPropertyDescription *contentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"COObject"];
	
	[contentsProperty setMultivalued: YES];
	[contentsProperty setOrdered: YES];
	[contentsProperty setPersistent: YES];
	
	[collection setPropertyDescriptions: A(contentsProperty)];

	return collection;	
}

- (BOOL)isContainer
{
	return YES;
}

- (BOOL) isOrdered
{
	return YES;
}

@end


@implementation COLibrary

@synthesize identifier;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COLibrary className]] == NO) 
		return collection;

	[collection setLocalizedDescription: _(@"Library")];

	ETPropertyDescription *idProperty = 
		[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"NSString"];
	[idProperty setPersistent: YES];

	[collection setPropertyDescriptions: A(idProperty)];

	return collection;	
}

- (void)dealloc
{
	DESTROY(identifier);
	[super dealloc];
}

- (BOOL)isLibrary
{
	return YES;
}

- (BOOL) isOrdered
{
	return NO;
}

@end


@implementation COTagLibrary

@synthesize tagGroups;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COTagLibrary className]] == NO) 
		return collection;

	ETPropertyDescription *tagGroups = 
		[ETPropertyDescription descriptionWithName: @"tagGroups" type: (id)@"COGroup"];
	[tagGroups setPersistent: YES];

	[collection setPropertyDescriptions: A(tagGroups)];

	return collection;	
}

- (id)init
{
	SUPERINIT;
	[self setIdentifier: kCOLibraryIdentifierTag];
	[self setName: _(@"Tags")];
	tagGroups = [[COGroup alloc] init];
	[tagGroups setName: _(@"Tag Groups")];
	return self;
}

- (void) becomePersistentInContext: (COPersistentRootEditingContext *)aContext
                        rootObject: (COObject *)aRootObject
{
	if ([self isPersistent])
		return;

	[super becomePersistentInContext: aContext rootObject: aRootObject];

	// TODO: Leverage the model description rather than hardcoding the aspects
	// TODO: Implement some strategy to recover in the case these aspects 
	// are already used as embedded objects in another root object. 
	ETAssert([[self tagGroups] isPersistent] == NO);
	[[self tagGroups] becomePersistentInContext: aContext rootObject: aRootObject];
}

- (void)dealloc
{
	DESTROY(tagGroups);
	[super dealloc];
}

@end


@implementation COEditingContext (COCommonLibraries)

- (COTagLibrary *)tagLibrary
{
	COTagLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierTag];

	if (lib == nil)
	{
		lib = [self insertObjectWithEntityName: @"Anonymous.COTagLibrary"];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

- (COLibrary *)photoLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierPhoto];

	if (lib == nil)
	{
		lib = [self insertObjectWithEntityName: @"Anonymous.COLibrary"];
		[lib setName: _(@"Photos")];
		[lib setIdentifier: kCOLibraryIdentifierPhoto];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

- (COLibrary *)musicLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierMusic];

	if (lib == nil)
	{
		lib = [self insertObjectWithEntityName: @"Anonymous.COLibrary"];
		[lib setName: _(@"Music")];
		[lib setIdentifier: kCOLibraryIdentifierMusic];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

@end

NSString * const kCOLibraryIdentifierTag = @"kCOLibraryIdentifierTag";
NSString * const kCOLibraryIdentifierPhoto = @"kCOLibraryIdentifierPhoto";
NSString * const kCOLibraryIdentifierMusic = @"kCOLibraryIdentifierMusic";
