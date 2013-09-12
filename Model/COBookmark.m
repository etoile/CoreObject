/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COBookmark.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COBookmark

@synthesize URL = _URL, lastVisitedDate = _lastVisitedDate, favIconData = _favIconData;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *bookmark = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add the
	// property descriptions that we will inherit through the parent
	if ([[bookmark name] isEqual: [COBookmark className]] == NO)
		return bookmark;
	
	ETPropertyDescription *URL =
		[ETPropertyDescription descriptionWithName: @"URL" type: (id)@"NSURL"];
	ETPropertyDescription *lastVisitedDate =
		[ETPropertyDescription descriptionWithName: @"lastVisitedDate" type: (id)@"NSDate"];
	ETPropertyDescription *favIconData =
		[ETPropertyDescription descriptionWithName: @"favIconData" type: (id)@"NSData"];

	NSArray *persistentProperties = A(URL, lastVisitedDate, favIconData);
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[bookmark setPropertyDescriptions: persistentProperties];

	return bookmark;
}


- (id) initWithURL: (NSURL *)aURL
{
	NILARG_EXCEPTION_TEST(aURL);
	SUPERINIT;
	_URL =  aURL;
	_favIconData =  [aURL favIconData];
	return self;
}

- (id) initWithURLFile: (NSString *)aFilePath
{
	// TODO: Finish to implement
	NSURL *URL = nil;
	return [self initWithURL: URL];
}

- (void)setURL: (NSURL *)aURL
{
	[self willChangeValueForProperty: @"URL"];
	_URL =  aURL;
	[self didChangeValueForProperty: @"URL"];
}

/** The URL is serialized as a NSString (rather than NSData through NSCoding) to 
support bookmark search based on URL text. */
- (NSString *)serializedURL
{
	return [_URL relativeString];
}

- (void)setSerializedURL: (NSString *)aURLString
{
	_URL =  [NSURL URLWithString: aURLString];
}

- (void)setLastVisitedDate:(NSDate *)aDate
{
	[self willChangeValueForProperty: @"lastVisitedDate"];
	_lastVisitedDate =  aDate;
	[self didChangeValueForProperty: @"lastVisitedDate"];
}

- (void)setFavIconData: (NSData *)favIconData
{
	[self willChangeValueForProperty: @"favIconData"];
	_favIconData =  favIconData;
	[self didChangeValueForProperty: @"favIconData"];
}

@end


@implementation  NSURL (COBookmark)

- (NSData *)favIconData
{
	NSURL *URL = [NSURL URLWithString: @"/favicon.ico" relativeToURL: self];
	return [NSData dataWithContentsOfURL: URL];
}

@end
