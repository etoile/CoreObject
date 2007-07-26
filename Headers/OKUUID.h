/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>

@interface NSString (OKUUID)

+ (NSString *) UUIDString;
+ (NSString *) UUIDStringWithURL: (NSURL *) url;

@end
