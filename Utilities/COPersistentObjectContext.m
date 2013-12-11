/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COPersistentObjectContext.h"

@implementation NSObject (COPersistentObjectContext)

- (BOOL)isEditingContext
{
	return NO;
}

- (BOOL)isPersistentRoot
{
	return NO;
}

- (BOOL)isObjectGraphContext
{
	return NO;
}

@end
