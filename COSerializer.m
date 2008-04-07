/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COSerializer.h"
#import "NSObject+CoreObject.h"

/* CoreObject Serializer */

@implementation COSerializer

- (size_t) storeObjectFromAddress: (void *)anAddress withName: (char *)aName
{
	id object = *(id *)anAddress;

	if ([object isCoreObject])
	{
		return [self storeCoreObject: object withName: aName];
	}
	else
	{
		return [super storeObjectFromAddress: anAddress withName: aName];
	}
}

- (size_t) storeCoreObject: (id)anObject withName: (char *)aName
{
	[[self backend] storeUUID: (char *)[[anObject UUID] UTF8String] 
	                 withName: aName];
	return COUUIDSize;
}

@end
