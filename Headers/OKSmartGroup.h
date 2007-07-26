/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "OKGroup.h"

extern NSString *kOKPredicateProperty;

@interface OKSmartGroup: OKGroup
{
	OKGroup *target;
	NSPredicate *predicate;
}

- (void) setPredicate: (NSPredicate *) predicate;
- (void) setTarget: (OKGroup *) group; 
@end

