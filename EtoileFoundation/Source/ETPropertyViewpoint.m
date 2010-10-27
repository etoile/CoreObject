/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  December 2007
	License:  Modified BSD (see COPYING)
 */

#import "ETPropertyViewpoint.h"
#import "Macros.h"
#import "NSObject+Etoile.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"


@implementation ETProperty

/** We don't post KVO notification when -setValue: is called, we only modify 
the property value in the property owner. */
+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString: @"value"])
	{
		return NO;
	}
	else
	{
		return [super automaticallyNotifiesObserversForKey: key];
	}
}

- (NSSet *) observableKeyPaths
{
	return S(@"value", @"representedObject");
}

// NOTE: By keeping track of the observer, we could do...
// [observer observeValueForKeyPath: @"value" ofObject: self change: change
//	context: NULL]
- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object 
	change: (NSDictionary *)change context: (void *)context
{
	NSParameterAssert([keyPath isEqualToString: [self name]]);

	ETLog(@"Will forward KVO property %@ change", keyPath);

	// NOTE: Invoking just -didChangeValueForKey: won't work
	[self willChangeValueForKey: @"value"];
	[self didChangeValueForKey: @"value"];
}

/** Returns a new autoreleased property viewpoint that represents the property 
identified by the given name in object. */
+ (id) propertyWithName: (NSString *)key representedObject: (id)object
{
	return AUTORELEASE([[ETProperty alloc] initWithName: key representedObject: object]);
}

/** <init />
Returns and initializes a new property viewpoint that represents the property 
identified by the given name in object. */
- (id) initWithName: (NSString *)key representedObject: (id)object
{
	NSParameterAssert(nil != key);
	SUPERINIT

	ASSIGN(_propertyName, key);
	[self setRepresentedObject: object];

	return self;
}

- (void) dealloc
{
	[self setRepresentedObject: nil]; /* Will end KVO observation */
	DESTROY(_propertyName);

	[super dealloc];
}

/** Returns the object to which the property belongs to. */
- (id) representedObject
{
	return _propertyOwner;
}

- (void) computeUseKVCWithObject: (id)object treatsAllKeysAsProperties: (BOOL)exposeAllKeys
{
	Class layoutItemClass = NSClassFromString(@"ETLayoutItem"); /* See EtoileUI */
	BOOL isLayoutItem = (Nil != layoutItemClass && [object isKindOfClass: layoutItemClass]);
 
	_usesKVC = (isLayoutItem || exposeAllKeys);
}

/** Sets the object to which the property belongs to. */
- (void) setRepresentedObject: (id)object
{
	NSString *name = [self name];

	NSParameterAssert(nil != name);

	if (nil != _propertyOwner)
	{

		[_propertyOwner removeObserver: self forKeyPath: name];
	}
	ASSIGN(_propertyOwner, object);

	[self computeUseKVCWithObject: object 
	    treatsAllKeysAsProperties: [self treatsAllKeysAsProperties]];

	if (nil != object)
	{
		[object addObserver: self forKeyPath: name options: 0 context: NULL];
	}
}

/** Returns whether all the keys for which the represented object is 
KVC-compliant should be considered as properties.

By default, returns NO.

When YES is returned, the property name can be any key (e.g. a dictionary key), 
otherwise only a property exposed by -propertyNames is valid. */
- (BOOL) treatsAllKeysAsProperties
{
	return _treatsAllKeysAsProperties;
}

/** Sets whether all the keys for which the represented object is 
KVC-compliant should be considered as properties.

See -treatsDictionaryKeysAsProperties. */
- (void) setTreatsAllKeysAsProperties: (BOOL)exposeAllKeys
{
	/* When treatsAllKeysAsProperties was NO and becomes YES, -value might start 
	   to return a non-nil value because the property value which was not 
	   exposed with PVC can be now retrieved with KVC. 
	   i.e. -valueForProperty: returns nil when the property isn't included in 
	   [representedObject properties]. */
	[self willChangeValueForKey: @"value"];

	_treatsAllKeysAsProperties = exposeAllKeys;
	[self computeUseKVCWithObject: [self representedObject]
	    treatsAllKeysAsProperties: exposeAllKeys];

	[self didChangeValueForKey: @"value"];
}

/** Returns the name used to declared property in the owner object. */
- (NSString *) name
{
	return _propertyName;
}

/** Returns the UTI type of the property value.

Allows to show the value type in an EtoileUI inspector. */
- (ETUTI *) type
{
	// NOTE: May be necessary to cache this value...
	// or [[self representedObject] typeForKey: [self name]]
	return [[self value] UTI];
}

/** Returns the value of the property. */
- (id) value
{
	if (_usesKVC)
	{
		return [[self representedObject] valueForKey: [self name]];
	}
	else /* Use PVC by default */
	{
		return [[self representedObject] valueForProperty: [self name]];
	}	
}

/** Sets the value of the property to be the given object value. */
- (void) setValue: (id)objectValue
{
	if (_usesKVC)
	{
		[[self representedObject] setValue: objectValue forKey: [self name]];
	}
	else /* Use PVC by default */
	{
		[[self representedObject] setValue: objectValue forProperty: [self name]];
	}	
}

/* Property Value Coding */

/** Returns 'property', 'name', 'type', 'value' and 'representedObject'.

See  -valueForProperty:. */
- (NSArray *) properties
{
	return A(@"property", @"name", @"type", @"value", @"representedObject");
}

/** Supports to view the property with several table columns such as 
'property', 'value' and 'type' (e.g. an EtoileUI inspector where property 
viewpoints are used as represented objects).

'property' is mapped to the property name. */
- (id) valueForProperty: (NSString *)key
{
	id value = nil;
	
	if ([[self properties] containsObject: key])
	{
		if ([key isEqual: @"property"])
		{
			value = [self name];
		}
		else /* name, type properties */
		{
			value = [self primitiveValueForKey: key];
		}
	}
	
	return value;
}

/** Supports to edit the property in a 'value' table column (e.g. in an EtoileUI inspector). */
- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = NO;
	
	if ([[self properties] containsObject: key])
	{
		// NOTE: name, type are read-only properties
		if ([key isEqual: @"value"])
		{
			[self setValue: value];
			result = YES;
		}
	}
	
	return result;
}

@end
