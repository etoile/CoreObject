/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/
#import "COGroup.h"
#import "COFileObject.h"

/* COCollection is a specialized group which allow you to add files into
   a place and organize them automatically.
   When a COFileObject or its subclass is added into COCollection,
   its file will be moved or copied into location of COCollection.
   By default, COCollection allows you to organize files based on added date.
   Subclass of COCollection can use different organization.
*/

extern NSString *collectionExtension;

@interface COCollection: COGroup
{
	NSString *_location;
	NSArray *_autoProperties;

	/** Cache, 
	    Not sure it really makes a difference, ask Yen-Ju... If it does, 
	    probably better to use a global var. */
	NSFileManager *_fm;
}

/* It will create one if it does not exist. */
- (id) initWithLocation: (NSString *) path;
- (NSString *) location;

- (BOOL) save;

/* Return path relative to location. Subclass should override this
   to change the style of sub-directories structures. */
- (NSString *) pathForFileObject: (COFileObject *) object;

/* When specified properties of any object changes,
   COCollection move file to new value of -pathForFileObject.
   Therefore, file associated with COFileObject is always organized
   based on properties. If nil, files will not be moved when properties changed.
 */ 
- (void) setAutoOrganizingProperties: (NSArray *) properties;
- (NSArray *) autoOrganizingProperties: (NSArray *) properties;

@end

