/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COMultiValue.h"
#import "GNUstep.h"

static NSString *kIdentifier = @"kIdentifier";
static NSString *kLabel = @"kLabel";
static NSString *kValue = @"kValue";

static NSString *pPrimaryIdentifierKey = @"PrimaryIdentifier";
static NSString *pMultiValueKey = @"MultiValue";

@implementation COMultiValue

- (id) initWithPropertyList: (NSDictionary *) propertyList
{
	self = [self init];

	id object;

	if ((object = [propertyList objectForKey: pMultiValueKey]))
	{
		if ([object isKindOfClass: [NSArray class]] == NO)
		{
			NSLog(@"Internal Error: pMultiValueKey is not an array");
			[self dealloc];
			return nil;
		}
	
	    NSEnumerator *e = [(NSArray *) object objectEnumerator];
	    NSMutableDictionary *d = nil;
	    while ((d = [e nextObject]))
	    {
	        [_values addObject: [d mutableCopy]];
	    }
	}

	if ((object = [propertyList objectForKey: pPrimaryIdentifierKey]))
		ASSIGN(_primaryIdentifier, object);

	return self;
}

- (NSMutableDictionary *) propertyList
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject: _values forKey: pMultiValueKey];
	if (_primaryIdentifier)
		[dict setObject: _primaryIdentifier forKey: pPrimaryIdentifierKey];
	return AUTORELEASE(dict);
}

- (NSString *) primaryIdentifier
{
	if ((_primaryIdentifier == nil) && [self count])
		ASSIGNCOPY(_primaryIdentifier, [self identifierAtIndex: 0]);
	return _primaryIdentifier;
}

- (NSString *) identifierAtIndex: (int) index
{
	return [[_values objectAtIndex: index] valueForKey: kIdentifier];
}

- (int) indexForIdentifier: (NSString *) identifier
{
	int i, count = [_values count];
	for (i = 0; i < count; i++)
	{
		if ([[[_values objectAtIndex: i] valueForKey: kIdentifier] isEqualToString: identifier])
		{
			return i;
		}
	}
	return NSNotFound;
}

- (NSString *) labelAtIndex: (int) index
{
	return [[_values objectAtIndex: index] valueForKey: kLabel];
}

- (id) valueAtIndex: (int) index
{
	return [[_values objectAtIndex: index] valueForKey: kValue];
}

- (unsigned int) count
{
	return [_values count];
}

- (COPropertyType) propertyType
{
	if ([self count])
	{
		id value = [self valueAtIndex: 0];
		if ([value isKindOfClass: [NSString class]])
			return kCOMultiStringProperty;
		else if ([value isKindOfClass: [NSNumber class]])
		{
			const char *oct = [(NSNumber *)value objCType];
			if ((oct == @encode(int)) ||
			    (oct == @encode(unsigned int)) ||
			    (oct == @encode(long)) ||
			    (oct == @encode(unsigned long)))
			{
				return kCOMultiIntegerProperty;
			}
			else if ((oct == @encode(float)) ||
			         (oct == @encode(double)))
			{
				return kCOMultiRealProperty;
			}
			else
			{
				return kCOErrorInProperty;
			}
		}
		else if ([value isKindOfClass: [NSDate class]])
		{
			return kCOMultiDateProperty;
		}
		else if ([value isKindOfClass: [NSArray class]])
		{
			return kCOMultiArrayProperty;
		}
		else if ([value isKindOfClass: [NSDictionary class]])
		{
			return kCOMultiDictionaryProperty;
		}
		else if ([value isKindOfClass: [NSData class]])
		{
			return kCOMultiDataProperty;
		}
	}
	
	return kCOErrorInProperty;
}

/* NSObject */
- (id) init
{
	self = [super init];
	_values = [[NSMutableArray alloc] init];
	_primaryIdentifier = nil;
	return self;
}

- (void) dealloc
{
	DESTROY(_values);
	DESTROY(_primaryIdentifier);
	[super dealloc];
}

- (NSString *) description
{
	return [_values description];
}

/* NSCopying */
- (id) copyWithZone: (NSZone *) zone
{
	COMultiValue *clone = [[COMultiValue allocWithZone: zone] init];
	NSMutableArray *array = [[NSMutableArray allocWithZone: zone] init];
	NSEnumerator *e = [_values objectEnumerator];
	NSMutableDictionary *d = nil;
	while ((d = [e nextObject]))
	{
		[array addObject: AUTORELEASE([d mutableCopyWithZone: zone])];
	}
	clone->_values = array;
	clone->_primaryIdentifier = [_primaryIdentifier copyWithZone: zone];
	return clone;
}

#if 0
/* NSMutableCopying */
- (id)mutableCopyWithZone: (NSZone *) zone
{
	COMultiValue *clone = [[COMultiValue allocWithZone: zone] init];
	int pi, i, count = [self count];
	id value = nil;
	NSString *label = nil;
	NSString *iden = nil;

	pi = [self indexForIdentifier: [self primaryIdentifier]];

	for (i = 0; i < count; i++)
	{
		value = [self valueAtIndex: i];
		label = [self labelAtIndex: i];
		iden = [clone addValue: value withLabel: label];
		if (pi == i)
			[clone setPrimaryIdentifier: iden];
	}
	return clone;
}
#endif

- (NSString *) _getIdentifier
{
	/* We do not use UUID here because it is too much.
	   A simple number should be efficient */
	NSArray *idens = [_values valueForKey: kIdentifier];
	if ([idens count] == 0)
	{
		return [NSString stringWithUTF8String: "0"];
	}

	NSString *iden = nil;
	int d = 0;
	while (1) 
	{
		iden = [NSString stringWithFormat: @"%d", d++];
		if ([idens containsObject: iden] == NO)
			break;
	}
	return iden;
}

- (NSString *) addValue: (id) value withLabel: (NSString *) label
{
	NSString *iden = [self _getIdentifier];
	if (iden == nil)
		return nil;

	NSMutableDictionary *d = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		value, kValue,
		label, kLabel,
		iden, kIdentifier,
		nil];
	[_values addObject: d];
	DESTROY(d);
	return iden;
}

- (NSString *) insertValue: (id) value withLabel: (NSString *) label 
                   atIndex: (int) index
{
	if ((index < 0) || (index >= [self count]))
		return nil;

	NSString *iden = [self _getIdentifier];
	if (iden == nil)
		return nil;

	NSMutableDictionary *d = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		value, kValue,
		label, kLabel,
		iden, kIdentifier,
		nil];
	[_values insertObject: d atIndex: index];
	DESTROY(d);
	return iden;
}

- (BOOL) replaceLabelAtIndex: (int) index withLabel: (NSString *) label
{
	if ((index > -1) && (index < [_values count]))
	{
		NSMutableDictionary *d = [_values objectAtIndex: index];
		[d setValue: label forKey: kLabel];
		[_values replaceObjectAtIndex: index withObject: d];
		return YES;
	}
	return NO;
}

- (BOOL) replaceValueAtIndex: (int) index withValue: (id) value
{
	if ((index > -1) && (index < [_values count]))
	{
		NSMutableDictionary *d = [_values objectAtIndex: index];
		[d setValue: value forKey: kValue];
		[_values replaceObjectAtIndex: index withObject: d];
		return YES;
	}
	return NO;
}

- (BOOL) removeValueAndLabelAtIndex: (int) index
{
	if ((index > -1) && (index < [_values count]))
	{
		[_values removeObjectAtIndex: index];
		return YES;
	}
	return NO;
}

- (BOOL) setPrimaryIdentifier: (NSString *) identifier
{
	/* We check the existence of identifier first */
	NSEnumerator *e = [_values objectEnumerator];
	NSDictionary *d = nil;
	while ((d = [e nextObject]))
	{
		if ([[d valueForKey: kIdentifier] isEqualToString: identifier])
		{
			ASSIGN(_primaryIdentifier, identifier);
			return YES;
		}
	}
	return NO;
}

@end
