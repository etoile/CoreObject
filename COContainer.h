/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COEditingContext.h>

/** 
 * @group Object Collection and Organization
 *
 * COContainer is a mutable, ordered, strong (contained objects can only be in 
 * one COContainer) collection class.
 */
@interface COContainer : COCollection
{

}

/**
 * Returns YES.
 */
- (BOOL)isContainer;

@end

/**
 * @group Object Collection and Organization
 *
 * COLibrary is used to represents libraries such as photo, music, tag etc.  
 * 
 * Contained objects can only be one library.
 *
 * The content is ordered (to ensure the object order remains stable in the UI 
 * without sorting it).
 */
@interface COLibrary : COContainer
{
	NSString *identifier;
}

@property (retain, nonatomic) NSString *identifier;

/**
 * Returns YES.
 */
- (BOOL)isLibrary;

/** @taskunit Private */

+ (NSSet *)additionalEntityDescriptions;

@end

@interface COTagLibrary : COLibrary
{
	COGroup *tagGroups;
}

/**
 * The tag categories used to organize the tags in the library.
 */
@property (retain, nonatomic) COGroup *tagGroups;

@end

/** 
 *@group Object Collection and Organization
 *
 * COEditingContext category that gives access to various common libraries.
 *
 * You can access these libraries as shown below too:
 *
 * <example>
 * [[editingContext libraryGroup] objectForIdentifier: kCOLibraryIdentifierMusic];
 * </example>
 */
@interface COEditingContext (COCommonLibraries)

/**
 * Returns a library listing the tags in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
- (COTagLibrary *)tagLibrary;
/**
 * Returns a library listing the bookmarks in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
- (COLibrary *)bookmarkLibrary;
/**
 * Returns a library listing the notes in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
- (COLibrary *)noteLibrary;
/**
 * Returns a group listing the pictures in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
- (COLibrary *)photoLibrary;
/**
 * Returns a group listing the music tracks in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
- (COLibrary *)musicLibrary;

@end

/** A unique identifier to mark the library listing the tags in the store.

See also -[COEditingContext tagLibrary]. */
extern NSString * const kCOLibraryIdentifierTag;
/** A unique identifier to mark the library listing the bookmarks in the store.
 
See also -[COEditingContext bookmarkLibrary]. */
extern NSString * const kCOLibraryIdentifierBookmark;
/** A unique identifier to mark the library listing the notes in the store.
 
See also -[COEditingContext noteLibrary]. */
extern NSString * const kCOLibraryIdentifierNote;
/** A unique identifier to mark the library listing the pictures in the store.

See also -[COEditingContext photoLibrary]. */
extern NSString * const kCOLibraryIdentifierPhoto;
/** A unique identifier to mark the library listing the music tracks in the store.

See also -[COEditingContext musicLibrary]. */
extern NSString * const kCOLibraryIdentifierMusic;
