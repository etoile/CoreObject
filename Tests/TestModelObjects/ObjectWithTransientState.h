/*
	Copyright (C) 2014 Quentin Mathe
 
	Date:  October 2014
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface ObjectWithTransientState : COObject
@property (nonatomic, readwrite) NSString *label;
@property (nonatomic, readwrite) NSArray *orderedCollection;
@property (nonatomic, readwrite) NSArray *derivedOrderedCollection;
@end
