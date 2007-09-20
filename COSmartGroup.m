/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COSmartGroup.h"
#import "GNUstep.h"

NSString *kCOPredicateProperty = @"kCOPredicateProperty";

@implementation COSmartGroup
- (void) _updateSmartGroup
{
	if (predicate && target)
	{
		NSMutableArray *ma = [self valueForProperty: kCOGroupChildrenProperty];
		[ma setArray: [target objectsMatchingPredicate: predicate]];
	}
}

- (void) objectChanged: (NSNotification *) not
{
	/* Avoid recursive */
	if ([[not object] isEqual: self]) 
		return;
	[self _updateSmartGroup];
}

- (void) setPredicate: (NSPredicate *) p
{
	ASSIGN(predicate, p);
	[self _updateSmartGroup];
}

- (void) setTarget: (COGroup *) group
{
	ASSIGN(target, group);
	[self _updateSmartGroup];
}

/* COGroup */
- (NSArray *) objectsMatchingPredicate: (NSPredicate *) p
{
	/* If we are ask to match predicate, update objects first */
	[self _updateSmartGroup];
	return [super objectsMatchingPredicate: p];
}

/* NSObject */
- (id) init
{
	self = [super init];
	[_nc addObserver: self
	     selector: @selector(objectChanged:)
	     name: kCOObjectChangedNotification
	     object: nil];
	return self;
}

- (void) dealloc
{
	[_nc removeObserver: self];
	DESTROY(predicate);
	DESTROY(target);
	[super dealloc];
}

@end

