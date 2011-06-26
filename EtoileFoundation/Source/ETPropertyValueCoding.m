/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  December 2007
	License:  Modified BSD (see COPYING)
 */


#import <EtoileFoundation/ETPropertyValueCoding.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileFoundation/EtoileCompatibility.h>


@implementation NSDictionary (ETPropertyValueCoding)
#if 0
- (NSArray *) propertyNames
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

- (NSArray *) propertyNames
{
	NSArray *properties = [NSArray arrayWithObjects: @"count", @"firstObject", 
		@"lastObject", nil];
	
	return [[super propertyNames] arrayByAddingObjectsFromArray: properties];
}

- (id) valueForProperty: (NSString *)key
{
	id value = nil;
	
	if ([[self propertyNames] containsObject: key])
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
	
	if ([[self propertyNames] containsObject: key])
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

- (NSArray *) propertyNames
{
	NSArray *properties = [NSArray arrayWithObjects: @"count", @"firstObject", 
		@"lastObject", nil];
	
	return [[super propertyNames] arrayByAddingObjectsFromArray: properties];
}

- (id) valueForProperty: (NSString *)key
{
	if ([[self propertyNames] containsObject: key])
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

	if ([[self propertyNames] containsObject: key])
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

