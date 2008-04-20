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

@end
