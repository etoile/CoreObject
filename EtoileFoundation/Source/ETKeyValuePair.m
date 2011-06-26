/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2010
	License: Modified BSD (see COPYING)
 */

#import "ETKeyValuePair.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"
#import "Macros.h"

@implementation ETKeyValuePair

/** Returns a new autoreleased pair with the given key and value. */
+ (id) pairWithKey: (NSString *)aKey value: (id)aValue
{
	return AUTORELEASE([[self alloc] initWithKey: aKey value: aValue]);
}

/** <init />
Initializes and returns a new pair with the given key and value. */
- (id) initWithKey: (NSString *)aKey value: (id)aValue
{
	SUPERINIT;
	ASSIGN(_key, aKey);
	ASSIGN(_value, aValue);
	return self;
}

- (id) init
{
	return nil;
}

- (void) dealloc
{
	DESTROY(_key);
	DESTROY(_value);
	[super dealloc];
}

/** Returns YES. */
- (BOOL) isKeyValuePair
{
	return YES;
}

/** Returns the pair identifier. */
- (NSString *) key
{
	return _key;
}

/** Sets the pair identifier. */
- (void) setKey: (NSString *)aKey
{
	ASSIGN(_key, aKey);
}

/** Returns the pair content. */
- (id) value
{
	return _value;
}

/** Sets the pair content. */
- (void) setValue: (id)aValue
{
	ASSIGN(_value, aValue);
}

/** Exposes <em>key</em> and <em>value</em> in addition to the inherited properties. */
- (NSArray *) propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: A(@"key", @"value")];
}

/** Returns the key. */
- (NSString *) displayName
{
	return _key;
}

@end


@implementation NSArray (ETKeyValuePairRepresentation)

/** Returns a dictionary where every ETKeyValuePair present in the array is 
turned into a key/value entry.

For every other object, its index in the array becomes its key in the 
dictionary.

The returned dictionary is autoreleased.

Raises an NSGenericException when the receiver contains an object which is not 
an ETKeyValuePair object. */
- (NSDictionary *) dictionaryRepresentation
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: [self count]];
	Class keyValuePairClass = [ETKeyValuePair class];

	FOREACH(self, pair, ETKeyValuePair *)
	{
		if ([pair isKindOfClass: keyValuePairClass] == NO)
		{
			[NSException raise: NSGenericException 
			            format: @"Array %@ must only contain ETKeyValuePair objects", 
			                    [self primitiveDescription]];
		}
		[dict setObject: [pair value] forKey: [pair key]];
	}

	return dict;
}

@end

@implementation NSDictionary (ETKeyValuePairRepresentation)

/** Returns an ETKeyValuePair array where every entry present in the dictionary 
is turned into a pair object.

The returned array is autoreleased. */
- (NSArray *) arrayRepresentation
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity: [self count]];
	NSEnumerator *keyEnumerator = [self keyEnumerator];

	FOREACHE(nil, key, NSString *, keyEnumerator)
	{
		id value = [self objectForKey: key];
 		ETKeyValuePair *pair = [[ETKeyValuePair alloc] initWithKey: key value: value];

		[array addObject: pair];
		RELEASE(pair);
	}

	return array;
}

@end

@implementation NSObject (ETKeyValuePair)

/** Returns whether the receiver is a ETKeyValuePair instance. */
- (BOOL) isKeyValuePair
{
	return NO;
}

@end
