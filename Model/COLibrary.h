/**
	Copyright (C) 2013 Quentin Mathe

	Date:  March 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COContainer.h>
#import <CoreObject/COEditingContext.h>

@class COGroup, COTagLibrary;

/**
 * @group Object Collection and Organization
 * @abstract COLibrary is used to represents libraries such as photo, music, 
 * tag etc.  
 *
 * Contained objects can only be in a single library. The content is ordered 
 * (to ensure the object order remains stable in the UI without sorting it).
 *
 * To access and change the objects in the library, use COCollection API. For 
 * example, -content returns all the objects in the library.
 */
@interface COLibrary : COContainer
{
	@private
	NSString *_identifier;
}


/** @taskunit Library Kind */


/**
 * An identifier that in most cases represents the library kind (to be precise, 
 * this is usually the content kind such as music, photo etc.).
 *
 * CoreObject declares various identifier constants corresponding to common 
 * library kinds.
 *
 * The identifier is used to look up the libraries in 
 * COEditingContext(COCommonLibraries) API. 
 */
@property (nonatomic, readwrite, strong) NSString *identifier;


/** @taskunit Type Querying */


/**
 * Returns YES.
 */
@property (nonatomic, readonly) BOOL isLibrary;


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


/** @taskunit Library List */


/**
 * Returns a group listing the libraries in the store.
 *
 * By default, it contains the libraries listed as methods among
 * COEditingContext(COCommonLibraries).
 *
 * See also COLibrary.
 */
@property (nonatomic, readonly) COGroup *libraryGroup;


/** @taskunit Accessing Libraries Directly */


/** 
 * Returns the library used to collect together the objects using the given 
 * entity description.
 *
 * For example, COBookmark entity or some subentity description would return 
 * -bookmarkLibrary.
 * 
 * For a nil entity description, raises an NSInvalidArgumentException.
 */
- (COLibrary *)libraryForContentType: (ETEntityDescription *)aType;
/**
 * Returns a library listing the tags in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
@property (nonatomic, readonly, strong) COTagLibrary *tagLibrary;
/**
 * Returns a library listing the bookmarks in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
@property (nonatomic, readonly, strong) COLibrary *bookmarkLibrary;
/**
 * Returns a library listing the notes in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
@property (nonatomic, readonly, strong) COLibrary *noteLibrary;
/**
 * Returns a group listing the pictures in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
@property (nonatomic, readonly, strong) COLibrary *photoLibrary;
/**
 * Returns a group listing the music tracks in the store.
 *
 * If the library doesn't exist yet, returns a new library but won't commit it.
 */
@property (nonatomic, readonly, strong) COLibrary *musicLibrary;

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
