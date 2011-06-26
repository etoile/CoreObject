/*
	Copyright (C) 2008 Günther Noack
 
	Author:  Günther Noack <guenther@unix-ag.uni-kl.de>
	Date:  November 2008
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#define DEFINE_STRINGS
#import "ETTranscript.h"
#include <stdio.h>

/*
 * A simple transcript class.
 *
 * Design rationale:
 * While not a very nice implementation from the Objective-C
 * perspective, it has the advantage of being very similar to
 * the usual Transcript interface as seen in many Smalltalk
 * implementations.
 *
 */
@implementation ETTranscript
+ (void) show: (NSObject*) anObject
{
	[self appendString: [anObject description]];
}

+ (void) appendString: (NSString*) aString
{
	id<ETTranscriptDelegate> delegate = 
		[[[NSThread currentThread] threadDictionary] 
			objectForKey: kTranscriptDelegate];
	if (nil == delegate)
	{
		printf("%s", [aString UTF8String]);
	}
	else
	{
		[delegate appendTranscriptString: aString];
	}
}

+ (void) cr
{
	[self appendString: @"\n"];
}
@end

