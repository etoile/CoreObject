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
		[self contentPropertyDescriptionWithName: @"contents" type: (id)@"COObject" opposite: nil];
	
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

+ (ETEntityDescription *)makeEntityDescriptionWithName: (NSString *)aName contentType: (NSString *)aType
{
	ETEntityDescription *collection = [ETEntityDescription descriptionWithName: aName];
	ETPropertyDescription *content =
		[self contentPropertyDescriptionWithName: @"contents" type: (id)aType opposite: nil];

	[collection setParent: (id)@"COLibrary"];
	[collection addPropertyDescription: content];

	return collection;
}
	 
+ (NSSet *)additionalEntityDescriptions
{
	return S([self makeEntityDescriptionWithName: @"COBookmarkLibrary" contentType: @"COBookmark"],
			 [self makeEntityDescriptionWithName: @"CONoteLibrary" contentType: @"COContainer"]);
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

- (void) becomePersistentInContext: (COPersistentRoot *)aContext
{
	if ([self isPersistent])
		return;

	[super becomePersistentInContext: aContext];

	// TODO: Leverage the model description rather than hardcoding the aspects
	// TODO: Implement some strategy to recover in the case these aspects 
	// are already used as embedded objects in another root object. 
	ETAssert([[self tagGroups] isPersistent] == NO);
	[[self tagGroups] becomePersistentInContext: aContext];
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
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COTagLibrary"] rootObject];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

- (COLibrary *)bookmarkLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierBookmark];
	
	if (lib == nil)
	{
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COBookmarkLibrary"] rootObject];
		[lib setName: _(@"Bookmarks")];
		[lib setIdentifier: kCOLibraryIdentifierBookmark];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

- (COLibrary *)noteLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierNote];
	
	if (lib == nil)
	{
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.CONoteLibrary"] rootObject];
		[lib setName: _(@"Notes")];
		[lib setIdentifier: kCOLibraryIdentifierNote];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

- (COLibrary *)photoLibrary
{
	COLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierPhoto];

	if (lib == nil)
	{
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COLibrary"] rootObject];
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
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COLibrary"] rootObject];
		[lib setName: _(@"Music")];
		[lib setIdentifier: kCOLibraryIdentifierMusic];
		[[self libraryGroup] addObject: lib];
	}
	return lib;
}

@end

NSString * const kCOLibraryIdentifierTag = @"kCOLibraryIdentifierTag";
NSString * const kCOLibraryIdentifierBookmark = @"kCOLibraryIdentifierBookmark";
NSString * const kCOLibraryIdentifierNote = @"kCOLibraryIdentifierNote";
NSString * const kCOLibraryIdentifierPhoto = @"kCOLibraryIdentifierPhoto";
NSString * const kCOLibraryIdentifierMusic = @"kCOLibraryIdentifierMusic";
