/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  March 2008
	License: Modified BSD (see COPYING)
 */

#import "NSURL+Etoile.h"
#import "NSString+Etoile.h"


@implementation NSURL (Etoile)

/** Returns a new URL instance by stripping the last path component of the 
receiver. */
- (NSURL *) parentURL
{
	return [NSURL fileURLWithPath: [[self path] stringByDeletingLastPathComponent]];
}

/** Returns the last path component of the path portion of the receiver. */
- (NSString *) lastPathComponent
{
	return [[self path] lastPathComponent];
}

/** Returns a new URL instance with aPath appended to the part partion of the 
receiver. */
- (NSURL *) URLByAppendingPath: (NSString *)aPath
{
	return [NSURL fileURLWithPath: [[self path] stringByAppendingPathComponent: aPath]];
}

@end

