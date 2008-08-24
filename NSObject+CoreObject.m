/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "NSObject+CoreObject.h"

@implementation NSObject (CoreObject)

- (BOOL) isCoreObject
{
	return NO;
}

- (BOOL) isManagedCoreObject
{
	return [self conformsToProtocol: @protocol(COManagedObject)];
}

- (BOOL) isCoreObjectProxy
{
	return NO;
}

/** Returns YES if the object is a fault. A fault object is a fake or marker 
    object used to denote the fact the real object isn't loaded in memory. */
- (BOOL) isFault
{
	return NO;
}

@end


@implementation ETUUID (CoreObject)

/** CoreObject uses UUID as fault markers. */
- (BOOL) isFault
{
	return YES;
}

@end
