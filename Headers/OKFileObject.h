/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "OKObject.h"

extern NSString *kOKFilePathProperty; // kOKStringProperty
extern NSString *kOKFileCreationDateProperty; // kOKDateProperty
extern NSString *kOKFileModificationDateProperty; // kOKDateProperty

@interface OKFileObject: OKObject
{
	/* Cache */
	NSFileManager *_fm;
}

- (id) initWithPath: (NSString *) path;

- (NSString *) path;
- (void) setPath: (NSString *) path;

@end
