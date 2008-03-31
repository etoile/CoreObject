/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COUtility.h"

/** Extends ETSerializer to handle the serialization of core objects. */
@interface COSerializer : ETSerializer
{

}

- (size_t) storeObjectFromAddress: (void *)anAddress withName: (char *)aName;
- (size_t) storeCoreObject: (id)anObject withName: (char *)aName;

@end
