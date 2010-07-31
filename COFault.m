/*
   Copyright (C) 2009 Quentin Mathe <qmathe gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COFault.h"
#import "COObjectContext.h"
#import "COMetadataServer.h"

@implementation COObjectFault

- (id) initWithFaultDescription: (NSDictionary *)aFaultDesc
                futureClassName: (NSString *)aClassName
{
	SUPERINIT;

	COObjectContext *context = AUTORELEASE([(COObjectContext *)[COObjectContext alloc] initWithUUID: 
		[aFaultDesc objectForKey: kCOContextCoreMetadata]]);

	ASSIGN(_uuid, [aFaultDesc objectForKey: kCOUUIDCoreMetadata]);
	ASSIGN(_futureClassName, aClassName);
	[context registerObject: self];

	return self;
}

/* Identity */

- (BOOL) isFault
{
	return YES;
}

- (NSString *) futureClassName
{
	return _futureClassName;
}

- (ETUUID *) UUID
{
	return _uuid;
}

- (unsigned int) hash
{
	return [[self UUID] hash];
}

- (BOOL) isEqual: (id)other
{
	if (other == nil || [other isKindOfClass: [self class]] == NO)
		return NO;

	// NOTE: Should we test the object version...
	return [_uuid isEqual: [self UUID]];
}

- (NSError *) load
{
	//object_setClass(self, NSClassFromString([self futureClassName]);
	return nil;
}

@end

