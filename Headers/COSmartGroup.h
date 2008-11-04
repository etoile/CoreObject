/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "COGroup.h"

extern NSString *kCOPredicateProperty;

@interface COSmartGroup: COGroup
{
	COGroup *target;
	NSPredicate *predicate;
}

- (void) setPredicate: (NSPredicate *)aPredicate;
- (void) setTarget: (COGroup *)aGroup;

@end

