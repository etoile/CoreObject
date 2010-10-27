/*
	ETPropertyValueCoding.m
	
	Property Value Coding protocol used by CoreObject and EtoileUI provides a
	unified API to implement access, mutation, delegation and late-binding of 
	properties.
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  December 2007
 
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <EtoileFoundation/ETPropertyValueCoding.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileFoundation/EtoileCompatibility.h>


@implementation NSDictionary (ETPropertyValueCoding)
#if 0
- (NSArray *) properties
{
	return [self allKeys];
}

- (id) valueForProperty: (NSString *)key
{
	return [self objectForKey: key];
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	return NO;
}
#else

- (NSArray *) properties
{
	NSArray *properties = [NSArray arrayWithObjects: @"count", @"firstObject", 
		@"lastObject", nil];
	
	return [[super properties] arrayByAddingObjectsFromArray: properties];
}

- (id) valueForProperty: (NSString *)key
{
	id value = nil;
	
	if ([[self properties] containsObject: key])
	{
		id (*NSObjectValueForKeyIMP)(id, SEL, id) = NULL;
		
		NSObjectValueForKeyIMP = (id (*)(id, SEL, id))[[NSObject class] 
			instanceMethodForSelector: @selector(valueForKey:)];
		value = NSObjectValueForKeyIMP(self, @selector(valueForKey:), key);
	}
	else
	{
		// TODO: Turn into an ETDebugLog which takes an object (or a class) to
		// to limit the logging to a particular object or set of instances.
		#ifdef DEBUG_PVC
		ETLog(@"WARNING: Found no value for property %@ in %@", key, self);
		#endif
	}
		
	return value;
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = YES;
	
	if ([[self properties] containsObject: key])
	{
		void (*NSObjectSetValueForKeyIMP)(id, SEL, id, id) = NULL;
		
		NSObjectSetValueForKeyIMP = (void (*)(id, SEL, id, id))[[NSObject class] 
			instanceMethodForSelector: @selector(setValue:forKey:)];
		NSObjectSetValueForKeyIMP(self, @selector(setValue:forKey:), value, key);
	}
	else
	{
		// TODO: Turn into an ETDebugLog which takes an object (or a class) to
		// to limit the logging to a particular object or set of instances.
		#ifdef DEBUG_PVC
		ETLog(@"WARNING: Found no value for property %@ in %@", key, self);
		#endif
	}
		
	return result;
}
#endif
@end

@implementation NSMutableDictionary (ETPropertyValueCoding)
#if 0
- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = YES;
	id object = value;
	
	// NOTE: Note sure we should really insert a null object when value is nil
	if (object == nil)
		object = [NSNull null];
	
	NS_DURING
		[self setObject: object forKey: key];
	NS_HANDLER
		result = NO;
		ETLog(@"Failed to set value %@ for property %@ in %@", value, key, self);
	NS_ENDHANDLER
	
	return result;
}
#endif
@end

@implementation NSArray (ETPropertyValueCoding)

- (NSArray *) properties
{
	NSArray *properties = [NSArray arrayWithObjects: @"count", @"firstObject", 
		@"lastObject", nil];
	
	return [[super properties] arrayByAddingObjectsFromArray: properties];
}

- (id) valueForProperty: (NSString *)key
{
	if ([[self properties] containsObject: key])
	{
		id (*NSObjectValueForKeyIMP)(id, SEL, id) = NULL;
		
		NSObjectValueForKeyIMP = (id (*)(id, SEL, id))[[NSObject class] 
			instanceMethodForSelector: @selector(valueForKey:)];
		return NSObjectValueForKeyIMP(self, @selector(valueForKey:), key);
	}
	else
	{
		// TODO: Turn into an ETDebugLog which takes an object (or a class) to
		// to limit the logging to a particular object or set of instances.
		#ifdef DEBUG_PVC
		ETLog(@"WARNING: Found no value for property %@ in %@", key, self);
		#endif
		return nil;
	}
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	return NO;
}

@end

@implementation NSMutableArray (ETPropertyValueCoding)

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = YES;

	if ([[self properties] containsObject: key])
	{
		void (*NSObjectSetValueForKeyIMP)(id, SEL, id, id) = NULL;
		
		NSObjectSetValueForKeyIMP = (void (*)(id, SEL, id, id))[[NSObject class] 
			instanceMethodForSelector: @selector(setValue:forKey:)];
		NSObjectSetValueForKeyIMP(self, @selector(setValue:forKey:), value, key);
	}
	else
	{
		// TODO: Turn into an ETDebugLog which takes an object (or a class) to
		// to limit the logging to a particular object or set of instances.
		#ifdef DEBUG_PVC
		ETLog(@"WARNING: Found no value for property %@ in %@", key, self);
		#endif
	}
	
	return result;
}

@end

#if 0

/* To extend NSClassDescription and NSManagedObject */
- (NSArray *) properties
{
	else if ([_modelObject respondsToSelector: @selector(entity)]
	 && [[(id)_modelObject entity] respondsToSelector: @selector(properties)])
	{
		/* Managed Objects have an entity which describes them */
		properties = (NSArray *)[[_modelObject entity] properties];
	}
	else if ([_modelObject respondsToSelector: @selector(classDescription)])
	{
		/* Any objects can declare a class description, so we try to use it */
		NSClassDescription *desc = [_modelObject classDescription];
		
		properties = [NSMutableArray arrayWithArray: [desc attributeKeys]];
		// NOTE: Not really sure we should include relationship keys
		[(NSMutableArray *)properties addObjectsFromArray: (NSArray *)[desc toManyRelationshipKeys]];
		[(NSMutableArray *)properties addObjectsFromArray: (NSArray *)[desc toOneRelationshipKeys]];
	}
}

#endif
