/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObject.h"

extern NSString *kCOFilePathProperty; // kCOStringProperty
extern NSString *kCOFileCreationDateProperty; // kCODateProperty
extern NSString *kCOFileModificationDateProperty; // kCODateProperty

@interface COFileObject: COObject
{
	/** Cache, 
	    Not sure it really makes a difference, ask Yen-Ju... If it does, 
	    probably better to use a global var. */
	NSFileManager *_fm;
}

- (id) initWithPath: (NSString *) path;

- (NSString *) path;
- (void) setPath: (NSString *) path;

@end
