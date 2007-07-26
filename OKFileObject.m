/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "OKFileObject.h"
#import "GNUstep.h"

NSString *kOKFilePathProperty = @"kOKFilePathProperty";
NSString *kOKFileCreationDateProperty = @"kOKFileCreationDateProperty";
NSString *kOKFileModificationDateProperty = @"kOKFileModificationDateProperty";

@implementation OKFileObject
+ (void) initialize
{
	/* We need to repeat what is in OKObject 
	   because GNU objc runtime will not call super for this method */
	NSDictionary *pt = [OKObject propertiesAndTypes];
	[OKFileObject addPropertiesAndTypes: pt];
	pt = [[NSDictionary alloc] initWithObjectsAndKeys:
	[NSNumber numberWithInt: kOKStringProperty], 
			kOKFilePathProperty,
	[NSNumber numberWithInt: kOKDateProperty], 
			kOKFileCreationDateProperty,
	[NSNumber numberWithInt: kOKDateProperty], 
			kOKFileModificationDateProperty,
			nil];
	[OKFileObject addPropertiesAndTypes: pt];
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
	return self;
}

- (NSString *) path
{
	return [self valueForProperty: kOKFilePathProperty];
}

- (void) setPath: (NSString *) path
{
	if (path == nil)
	{
		[self removeValueForProperty: kOKFilePathProperty];
	}
	else
	{
		[self setValue: path forProperty: kOKFilePathProperty];
	}
}

@end
