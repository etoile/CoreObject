/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>,
			 Eric Wasylishen <ewasylishen@gmail.com>
	Date:  October 2013
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface KeyedRelationshipModel : COObject
@property (nonatomic, strong) NSDictionary *entries;
@end