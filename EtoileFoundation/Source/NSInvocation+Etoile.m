/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  April 2008
	License: Modified BSD (see COPYING)
 */

#import "NSInvocation+Etoile.h"
#import "Macros.h"


@implementation NSInvocation (Etoile)

/** Creates and returns a new invocation ready to be invoked by taking in 
input all mandatory parameters.

This method is only usable for selector for which the method signature doesn't 
declare arguments with C-intrisic types. In other words, the method to be 
invoked has to take only objects in parameter.

TODO: May be implement support of the C-intrisic types that can be boxed 
into NSValue instances, by handling the unboxing of the NSValue instances if 
needed. The code should still work well if the method takes an NSValue object in 
argument. */
+ (id) invocationWithTarget: (id)target 
                   selector: (SEL)selector 
                  arguments: (NSArray *)args
{
	NSInvocation *inv = [NSInvocation invocationWithMethodSignature: 
		[target methodSignatureForSelector: selector]];
	int i = 2;

	[inv setTarget: target];
	[inv setSelector: selector];
	FOREACHI(args, object)
	{
		[inv setArgument: &object atIndex: i];
		i++;
	}

	return inv;
}

@end
