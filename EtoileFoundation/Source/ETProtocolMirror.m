/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import "ETProtocolMirror.h"
#import "ETMethodMirror.h"
#import "ETUTI.h"
#import "Macros.h"
#import "NSObject+Trait.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation ETProtocolMirror

+ (void) initialize
{
	if (self != [ETProtocolMirror class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (id) mirrorWithProtocol: (Protocol *)protocol
{
	return [[[ETProtocolMirror alloc] initWithProtocol: protocol] autorelease];
}

- (id) initWithProtocol: (Protocol *)protocol
{
	SUPERINIT
	_protocol = protocol;
	return self;
}
- (BOOL) isEqual: (id)obj
{
	return [obj isMemberOfClass: [ETProtocolMirror class]] && 
		[[obj name] isEqualToString: [self name]];
}
- (NSUInteger) hash
{
	return [[self name] hash];
}
- (NSString *) name
{
	return [NSString stringWithUTF8String: protocol_getName(_protocol)];
}
- (NSArray *) ancestorProtocolMirrors
{
	unsigned int protocolsCount;
	Protocol **protocols = protocol_copyProtocolList(_protocol, &protocolsCount);
	NSMutableArray *mirrors = [NSMutableArray arrayWithCapacity: protocolsCount];
	for (int i=0; i<protocolsCount; i++)
	{
		[mirrors addObject: [ETProtocolMirror mirrorWithProtocol: protocols[i]]];
	}
	if (protocols != NULL)
	{
		free(protocols);
	}
	return mirrors;
}
- (NSArray *) allAncestorProtocolMirrors
{
	NSArray *ancestorProtocolMirrors = [self ancestorProtocolMirrors];
	// Using a set to remove duplicates from the result
	NSMutableSet *mirrors = [NSMutableSet setWithArray: ancestorProtocolMirrors];
	FOREACH(ancestorProtocolMirrors, ancestor, ETProtocolMirror *)
	{
		[mirrors addObjectsFromArray: [ancestor allAncestorProtocolMirrors]];
	}
	return [mirrors allObjects];
}
- (NSArray *) methodMirrors
{
	// TODO: Fetch non-required methods from the protocol description
	unsigned int instanceMethodsCount, classMethodsCount;
	struct objc_method_description *instanceMethods = 
		protocol_copyMethodDescriptionList(_protocol, YES, YES, &instanceMethodsCount);
	struct objc_method_description *classMethods = 
		protocol_copyMethodDescriptionList(_protocol, YES, NO, &classMethodsCount);
	NSMutableArray *mirrors = [NSMutableArray arrayWithCapacity: instanceMethodsCount + classMethodsCount];

	for (int i=0; i<instanceMethodsCount; i++)
	{
		[mirrors addObject: [ETMethodDescriptionMirror mirrorWithMethodName: sel_getName(instanceMethods[i].name)
															  isClassMethod: NO]];
	}
	for (int i=0; i<classMethodsCount; i++)
	{
		[mirrors addObject: [ETMethodDescriptionMirror mirrorWithMethodName: sel_getName(classMethods[i].name)
															  isClassMethod: YES]];
	}

	if (instanceMethods != NULL)
	{
		free(instanceMethods);
	}
	if (classMethods != NULL)
	{
		free(classMethods);
	}
	return mirrors;
}
- (NSArray *) allMethodMirrors
{
	NSArray *ancestorProtocolMirrors = [self ancestorProtocolMirrors];
	NSMutableArray *mirrors = AUTORELEASE([[self methodMirrors] mutableCopy]);
	FOREACH(ancestorProtocolMirrors, ancestor, ETProtocolMirror *)
	{
		[mirrors addObjectsFromArray: [ancestor allMethodMirrors]];
	}
	return mirrors;
}
- (ETUTI *) type
{
	return [ETUTI typeWithString: @"org.etoile.objc.protocol"];
}

/* Collection Protocol */

- (id) content
{
	return [self contentArray];
}

- (NSArray *) contentArray
{
	return [self allMethodMirrors];
}

/* Property-value coding */

- (NSArray *) propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
			A(@"name")];
}

- (NSString *) description
{
	return [NSString stringWithFormat:
			@"Protocol mirror on %@",
			[self name]];
}
@end


