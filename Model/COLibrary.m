/*
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "COLibrary.h"
#import "COObjectGraphContext.h"
#import "COSmartGroup.h"
#import "COTag.h"
#import "COPersistentRoot.h"

@implementation COLibrary

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *collection = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add the 
    // property descriptions that we will inherit through the parent
    if (![collection.name isEqual: [COLibrary className]])
        return collection;

    [collection setLocalizedDescription: _(@"Library")];

    ETPropertyDescription *idProperty =
        [ETPropertyDescription descriptionWithName: @"identifier" typeName: @"NSString"];
    idProperty.persistent = YES;

    collection.propertyDescriptions = @[idProperty];

    return collection;
}

+ (ETEntityDescription *)makeEntityDescriptionWithName: (NSString *)aName
                                           contentType: (NSString *)aType
{
    ETEntityDescription *collection = [ETEntityDescription descriptionWithName: aName];
    ETPropertyDescription *objects =
        [self contentPropertyDescriptionWithName: @"objects"
                                            type: (id)aType
                                        opposite: nil];

    collection.parentName = @"COLibrary";
    [collection addPropertyDescription: objects];

    return collection;
}

+ (NSSet *)additionalEntityDescriptions
{
    return S([self makeEntityDescriptionWithName: @"COBookmarkLibrary" contentType: @"COBookmark"],
             [self makeEntityDescriptionWithName: @"CONoteLibrary" contentType: @"COContainer"]);
}

- (BOOL)isLibrary
{
    return YES;
}

// FIXME: Should be able to use @dynamic and let CoreObject generate the accessors,
// but we can't, because COObject also implements -identifier. See TODO.

- (NSString *)identifier
{
    return _identifier;
}

- (void)setIdentifier: (NSString *)anIdentifier
{
    [self willChangeValueForProperty: @"identifier"];
    _identifier = anIdentifier;
    [self didChangeValueForProperty: @"identifier"];
}

@end


@implementation COEditingContext (COCommonLibraries)

// TODO: Probably need to be turned into a normal group or use some sorting to 
// ensure the libraries don't appear in a random order in the UI (e.g. accross
// application launches).
- (COSmartGroup *)libraryGroup
{
    COSmartGroup *group = [[COSmartGroup alloc]
        initWithObjectGraphContext: _internalTransientObjectGraphContext];
    [group setName: _(@"All Objects")];
    group.targetCollection = [(id)[[self.persistentRoots mappedCollection] rootObject] allObjects];
#ifdef GNUSTEP
    group.predicate = [NSPredicate predicateWithFormat: @"isLibrary == YES"];
#else
    group.predicate = [NSPredicate predicateWithBlock: ^BOOL(id object, NSDictionary *bindings)
    {
        return [object isLibrary];
    }];
#endif
    return group;
}

- (COLibrary *)libraryForContentType: (ETEntityDescription *)aType
{
    NILARG_EXCEPTION_TEST(aType);

    for (COLibrary *lib in self.libraryGroup)
    {
        ETEntityDescription *contentType =
            [lib.entityDescription propertyDescriptionForName: lib.contentKey].type;

        if ([aType isKindOfEntity: contentType])
            return lib;
    }
    return nil;
}

- (COTagLibrary *)tagLibrary
{
    COTagLibrary *lib = [self.libraryGroup objectForIdentifier: kCOLibraryIdentifierTag];

    if (lib == nil)
    {
        lib = [self insertNewPersistentRootWithEntityName: @"COTagLibrary"].rootObject;
    }
    return lib;
}

- (COLibrary *)bookmarkLibrary
{
    COLibrary *lib = [self.libraryGroup objectForIdentifier: kCOLibraryIdentifierBookmark];

    if (lib == nil)
    {
        lib = [self insertNewPersistentRootWithEntityName: @"COBookmarkLibrary"].rootObject;
        [lib setName: _(@"Bookmarks")];
        lib.identifier = kCOLibraryIdentifierBookmark;
    }
    return lib;
}

- (COLibrary *)noteLibrary
{
    COLibrary *lib = [self.libraryGroup objectForIdentifier: kCOLibraryIdentifierNote];

    if (lib == nil)
    {
        lib = [self insertNewPersistentRootWithEntityName: @"CONoteLibrary"].rootObject;
        [lib setName: _(@"Notes")];
        lib.identifier = kCOLibraryIdentifierNote;
    }
    return lib;
}

- (COLibrary *)photoLibrary
{
    COLibrary *lib = [self.libraryGroup objectForIdentifier: kCOLibraryIdentifierPhoto];

    if (lib == nil)
    {
        lib = [self insertNewPersistentRootWithEntityName: @"COLibrary"].rootObject;
        [lib setName: _(@"Photos")];
        lib.identifier = kCOLibraryIdentifierPhoto;
    }
    return lib;
}

- (COLibrary *)musicLibrary
{
    COLibrary *lib = [self.libraryGroup objectForIdentifier: kCOLibraryIdentifierMusic];

    if (lib == nil)
    {
        lib = [self insertNewPersistentRootWithEntityName: @"COLibrary"].rootObject;
        [lib setName: _(@"Music")];
        lib.identifier = kCOLibraryIdentifierMusic;
    }
    return lib;
}

@end

NSString *const kCOLibraryIdentifierTag = @"kCOLibraryIdentifierTag";
NSString *const kCOLibraryIdentifierBookmark = @"kCOLibraryIdentifierBookmark";
NSString *const kCOLibraryIdentifierNote = @"kCOLibraryIdentifierNote";
NSString *const kCOLibraryIdentifierPhoto = @"kCOLibraryIdentifierPhoto";
NSString *const kCOLibraryIdentifierMusic = @"kCOLibraryIdentifierMusic";
