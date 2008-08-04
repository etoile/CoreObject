/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COUtility.h"

#define CODeserializer ETDeserializer

@interface ETDeserializer (CODeserializer)

+ (id) defaultCoreObjectDeserializer;
+ (id) defaultCoreObjectDeserializerWithURL: (NSURL *)aURL;
+ (id) deserializeObjectWithURL: (NSURL *)aURL;

@end
