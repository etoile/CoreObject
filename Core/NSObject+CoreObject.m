/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */


#import "NSObject+CoreObject.h"

@implementation NSObject (CoreObject)

- (BOOL)isEditingContext
{
	return NO;
}

- (BOOL)isPersistentRoot
{
	return NO;
}

- (BOOL)isTrack
{
	return NO;
}

@end
