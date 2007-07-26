/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/
#import "OKGroup.h"
#import "OKFileObject.h"

/* OKCollection is a specialized group which allow you to add files into
   a place and organize them automatically.
   When a OKFileObject or its subclass is added into OKCollection,
   its file will be moved or copied into location of OKCollection.
   By default, OKCollection allows you to organize files based on added date.
   Subclass of OKCollection can use different organization.
*/

extern NSString *collectionExtension;

@interface OKCollection: OKGroup
{
	NSString *_location;
	NSArray *_autoProperties;

	/* Cache */
	NSFileManager *_fm;
}

/* It will create one if it does not exist. */
- (id) initWithLocation: (NSString *) path;
- (NSString *) location;

- (BOOL) save;

/* Return path relative to location. Subclass should override this
   to change the style of sub-directories structures. */
- (NSString *) pathForFileObject: (OKFileObject *) object;

/* When specified properties of any object changes,
   OKCollection move file to new value of -pathForFileObject.
   Therefore, file associated with OKFileObject is always organized
   based on properties. If nil, files will not be moved when properties changed.
 */ 
- (void) setAutoOrganizingProperties: (NSArray *) properties;
- (NSArray *) autoOrganizingProperties: (NSArray *) properties;

@end

