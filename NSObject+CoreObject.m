/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "NSObject+CoreObject.h"

@implementation NSObject (CoreObject)

/** Returns whether the object is a core object.
    The core object can be either transient or persistent. A persistent core 
    object is called a managed core object, see -isManagedCoreObject.
    Returns NO by default. */ 
- (BOOL) isCoreObject
{
	return NO;
}

/** Returns whether the object is an object whose persistency is managed by 
    CoreObject. COObject class and COProxy are the two classes of managed 
    core objects, that are bundled in the framework.
    Returns YES if the receiver conforms to COManagedObject, otherwise returns 
    NO by default. */
- (BOOL) isManagedCoreObject
{
	return [self conformsToProtocol: @protocol(COManagedObject)];
}

/** Returns whether the object is the CoreObject proxy that wraps a model object 
    to manage its persistency.
    Returns NO by default. */
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
