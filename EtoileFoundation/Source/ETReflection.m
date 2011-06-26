/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>
#import "ETReflection.h"
#import "ETClassMirror.h"
#import "ETInstanceVariableMirror.h"
#import "ETObjectMirror.h"
#import "ETProtocolMirror.h"

@implementation ETReflection

+ (id <ETObjectMirror>) reflectObject: (id)anObject
{
	return [ETObjectMirror mirrorWithObject: anObject];
}

+ (id <ETClassMirror>) reflectClass: (Class)aClass
{
	return [ETClassMirror mirrorWithClass: aClass];
}

+ (id <ETClassMirror>) reflectClassWithName: (NSString *)className
{
	id class = objc_getClass([className UTF8String]);
	if (class != nil)
	{
		return [ETClassMirror mirrorWithClass: (Class)class];
	}
	return nil;
}

+ (id <ETProtocolMirror>) reflectProtocolWithName: (NSString *)protocolName
{
	Protocol *protocol = objc_getProtocol([protocolName UTF8String]);
	if (protocol != nil)
	{
		return [ETProtocolMirror mirrorWithProtocol: protocol];
	}
	return nil;
}

+ (id <ETProtocolMirror>) reflectProtocol: (Protocol *)aProtocol
{
	if (aProtocol != nil)
	{
		return [ETProtocolMirror mirrorWithProtocol: aProtocol];
	}
	return nil;
}

@end

