/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COContainer.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COContainer

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COContainer className]] == NO) 
		return collection;
	
	ETPropertyDescription *contentsProperty = 
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.COObject"];
	
	[contentsProperty setMultivalued: YES];
	[contentsProperty setOpposite: (id)@"Anonymous.COObject.parentContainer"]; // FIXME: just 'parent' should work...
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

	ETPropertyDescription *idProperty = 
		[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"Anonymous.NSString"];
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


@implementation COEditingContext (COCommonLibraries)

- (COLibrary *)tagLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierTag];

	if (lib == nil)
	{
		lib = [self insertObjectWithEntityName: @"Anonymous.COLibrary"];
		[lib setName: _(@"Tags")];
		[lib setIdentifier: kCOLibraryIdentifierTag];
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
