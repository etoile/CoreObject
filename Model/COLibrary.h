/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COContainer.h>
#import <CoreObject/COEditingContext.h>

@class COTagLibrary;

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

@property (strong, nonatomic) NSString *identifier;

/**
 * Returns YES.
 */
- (BOOL)isLibrary;

/** @taskunit Private */

+ (NSSet *)additionalEntityDescriptions;

@end

/** 
 * @group Object Collection and Organization
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
 * @taskunit Library List
 */

/**
 * Returns a group listing the libraries in the store.
 *
 * By default, it contains the libraries listed as methods among
 * COEditingContext(COCommonLibraries).
 *
 * See also COLibrary.
 */
@property (nonatomic, readonly) COGroup *libraryGroup;

/**
 * @taskunit Accessing Libraries Directly
 */

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
