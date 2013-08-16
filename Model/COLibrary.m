/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COLibrary.h"
#import "COGroup.h"
#import "COObjectGraphContext.h"
#import "COTag.h"

#pragma GCC diagnostic ignored "-Wprotocol"

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


@implementation COEditingContext (COCommonLibraries)

// TODO: Probably need to be turned into a normal group or use some sorting to 
// ensure the libraries don't appear in a random order in the UI (e.g. accross
// application launches).
- (COSmartGroup *)libraryGroup
{
	COSmartGroup *group = [[[COSmartGroup alloc]
		initWithObjectGraphContext: [COObjectGraphContext objectGraphContext]] autorelease];
	[group setName: _(@"All Objects")];
	[group setTargetCollection: [[[[self persistentRoots] mappedCollection] rootObject] allObjects]];
	[group setQuery: [COQuery queryWithPredicateBlock: ^ BOOL (id object, NSDictionary *bindings)
	{
		return [object isLibrary];
	}]];
	return group;
}

- (COTagLibrary *)tagLibrary
{
	COTagLibrary *lib = [[self libraryGroup] objectForIdentifier: kCOLibraryIdentifierTag];

	if (lib == nil)
	{
		lib = [[self insertNewPersistentRootWithEntityName: @"Anonymous.COTagLibrary"] rootObject];
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
	}
	return lib;
}

@end

NSString * const kCOLibraryIdentifierTag = @"kCOLibraryIdentifierTag";
NSString * const kCOLibraryIdentifierBookmark = @"kCOLibraryIdentifierBookmark";
NSString * const kCOLibraryIdentifierNote = @"kCOLibraryIdentifierNote";
NSString * const kCOLibraryIdentifierPhoto = @"kCOLibraryIdentifierPhoto";
NSString * const kCOLibraryIdentifierMusic = @"kCOLibraryIdentifierMusic";
