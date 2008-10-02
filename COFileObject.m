/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COFileObject.h"
#import "GNUstep.h"

NSString *kCOFilePathProperty = @"kCOFilePathProperty";
NSString *kCOFileCreationDateProperty = @"kCOFileCreationDateProperty";
NSString *kCOFileModificationDateProperty = @"kCOFileModificationDateProperty";

@implementation COFileObject

+ (void) initialize
{
	/* We need to register COObject properties and types by calling super 
	   because GNU objc runtime will not call +initialize on superclass as 
	   NeXT runtime does. */
	[super initialize];
	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
	[NSNumber numberWithInt: kCOStringProperty], 
			kCOFilePathProperty,
	[NSNumber numberWithInt: kCODateProperty], 
			kCOFileCreationDateProperty,
	[NSNumber numberWithInt: kCODateProperty], 
			kCOFileModificationDateProperty,
			nil];
	[self addPropertiesAndTypes: pt];
	DESTROY(pt);
}

- (id) init
{
	self = [super init];
	_fm = [NSFileManager defaultManager];
	return self;
}

- (id) initWithPath: (NSString *) path
{
	self = [self init];

	/* Make sure file exists */
	if ([_fm fileExistsAtPath: path] == NO)
	{
		NSLog(@"File does not exists at %@", path);
		[self dealloc];
		return nil;
	}
	[self setPath: path];

	[self tryStartPersistencyIfInstanceOfClass: [COFileObject class]];

	return self;
}

- (NSString *) path
{
	return [self valueForProperty: kCOFilePathProperty];
}

- (void) setPath: (NSString *) path
{
	if (path == nil)
	{
		[self removeValueForProperty: kCOFilePathProperty];
	}
	else
	{
		[self setValue: path forProperty: kCOFilePathProperty];
	}
}

/* Serialization (EtoileSerialize)
   TODO: this code is copied/pasted in COCollection.m, figure out a way to 
   share it. */

- (BOOL) serialize: (char *)aVariable using: (ETSerializer *)aSerializer
{
	if ([super serialize: aVariable using: aSerializer])
		return YES;

	if (strcmp(aVariable, "_fm") == 0)
	{
		return YES; /* Should not be automatically serialized (manual) */
	}

	return NO; /* Serializer handles the ivar */
}

- (void) finishedDeserializing
{
	[super finishedDeserializing];
	_fm = [NSFileManager defaultManager];
}

@end
