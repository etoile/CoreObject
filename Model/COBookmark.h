/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

/**
 * @group Built-in Object Types
 *
 * COBookmark represents a URL-based link.
 *
 * COObject API includes the bookmark name, creation date and 
 * modification date. For example, see -[COObject name].
 */
@interface COBookmark : COObject
{
	@private
	NSURL *_URL;
	NSDate *_lastVisitedDate;
	NSData *_favIconData;
}

/** @taskunit Initialization */

/**
 * <init />
 * Intializes and returns a bookmark representing the URL.
 *
 * For a nil URL, raises an NSInvalidArgumentException.
 */
- (id) initWithURL: (NSURL *)aURL;
/**
 * Intializes and returns a bookmark from the URL location file at the given 
 * path.
 *
 * Files using extensions such as .webloc or .url are URL location files.
 *
 * When no URL can be extracted from the URL location file, returns nil.
 *
 * For a nil URL, raises an NSInvalidArgumentException.
 */
- (id) initWithURLFile: (NSString *)aFilePath;

/** @taskunit Bookmark Properties */

/**
 * The bookmark URL.
 *
 * This property is persistent and never nil.
 */
@property (nonatomic, strong) NSURL *URL;
/**
 * The last time the URL was visited.
 *
 * For example, each time a web page is loaded, a browser can udpate this 
 * property.
 *
 * This property is persistent.
 */
@property (nonatomic, strong) NSDate *lastVisitedDate;
/**
 * The image data for the fav icon bound to the ULR.
 *
 * You would usually retrieve it from the URL. It is the small icon 
 * displayed in a web browser address bar.
 *
 * This property is persistent.
 */
@property (nonatomic, strong) NSData *favIconData;

@end

/**
 * CoreObject additions for NSURL.
 */
@interface NSURL (COBookmark)
/**
 * Returns the image data of the fav icon that symbolizes the given URL. 
 */
- (NSData *)favIconData;
@end
