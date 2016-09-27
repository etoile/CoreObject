/*
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "COBookmark.h"

@implementation COBookmark

@synthesize URL = _URL, lastVisitedDate = _lastVisitedDate, favIconData = _favIconData;

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *bookmark = [self newBasicEntityDescription];
    
    // For subclasses that don't override -newEntityDescription, we must not add the
    // property descriptions that we will inherit through the parent
    if (![bookmark.name isEqual: [COBookmark className]])
        return bookmark;
    
    ETPropertyDescription *URL =
        [ETPropertyDescription descriptionWithName: @"URL" typeName: @"NSURL"];
    ETPropertyDescription *lastVisitedDate =
        [ETPropertyDescription descriptionWithName: @"lastVisitedDate" typeName: @"NSDate"];
    ETPropertyDescription *favIconData =
        [ETPropertyDescription descriptionWithName: @"favIconData" typeName: @"NSData"];

    NSArray *persistentProperties = @[URL, lastVisitedDate, favIconData];
    
    [[persistentProperties mappedCollection] setPersistent: YES];
    bookmark.propertyDescriptions = persistentProperties;

    return bookmark;
}


- (instancetype) initWithURL: (NSURL *)aURL
{
    NILARG_EXCEPTION_TEST(aURL);
    SUPERINIT;
    _URL =  aURL;
    _favIconData =  aURL.favIconData;
    return self;
}

- (instancetype) initWithURLFile: (NSString *)aFilePath
{
    // TODO: Finish to implement
    NSURL *URL = nil;
    return [self initWithURL: URL];
}

- (void)setURL: (NSURL *)aURL
{
    [self willChangeValueForProperty: @"URL"];
    _URL =  [aURL copy];
    [self didChangeValueForProperty: @"URL"];
}

/** The URL is serialized as a NSString (rather than NSData through NSCoding) to 
support bookmark search based on URL text. */
- (NSString *)serializedURL
{
    return _URL.relativeString;
}

- (void)setSerializedURL: (NSString *)aURLString
{
    _URL = (aURLString != nil ? [NSURL URLWithString: aURLString] : nil);
}

- (void)setLastVisitedDate:(NSDate *)aDate
{
    [self willChangeValueForProperty: @"lastVisitedDate"];
    _lastVisitedDate =  [aDate copy];
    [self didChangeValueForProperty: @"lastVisitedDate"];
}

- (void)setFavIconData: (NSData *)favIconData
{
    [self willChangeValueForProperty: @"favIconData"];
    _favIconData =  [favIconData copy];
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
