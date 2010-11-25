#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COGroup.h"
#import "COCollection.h"

@implementation COObject

+ (void)initialize
{
	if (self == [COObject class])
	{
		// COObject entity description
		
		ETEntityDescription *object = [ETEntityDescription descriptionWithName: @"COObject"];
		
		ETPropertyDescription *parentGroupProperty = [ETPropertyDescription descriptionWithName: @"parentGroup"
																						   type: (id)@"Anonymous.COGroup"];
		[parentGroupProperty setIsContainer: YES];
		[parentGroupProperty setMultivalued: NO];
	
		ETPropertyDescription *parentCollectionsProperty = [ETPropertyDescription descriptionWithName: @"parentCollections"
																								type: (id)@"Anonymous.COCollection"];
		
		[parentCollectionsProperty setMultivalued: YES];
		
		[object setPropertyDescriptions: A(parentGroupProperty, parentCollectionsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: object];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: object
																   forClass: [COObject class]];
		
		// COGroup entity description
		
		ETEntityDescription *group = [ETEntityDescription descriptionWithName: @"COGroup"];
		[group setParent: (id)@"Anonymous.COObject"];
		
		ETPropertyDescription *groupContentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																						type: (id)@"Anonymous.COObject"];
		[groupContentsProperty setMultivalued: YES];
		[groupContentsProperty setOpposite: (id)@"Anonymous.COObject.parentGroup"]; // FIXME: just 'parent' should work...
		[groupContentsProperty setOrdered: YES];
		
		[group setPropertyDescriptions: A(groupContentsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: group];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: group
																   forClass: [COGroup class]];
		
		// COCollection entity description
		
		ETEntityDescription *collection = [ETEntityDescription descriptionWithName: @"COCollection"];
		[collection setParent: (id)@"Anonymous.COObject"];
		
		ETPropertyDescription *collectionContentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																						type: (id)@"Anonymous.COObject"];
		[collectionContentsProperty setMultivalued: YES];
		[collectionContentsProperty setOpposite: (id)@"Anonymous.COObject.parentCollections"]; // FIXME: just 'parentCollections' should work...
		[collectionContentsProperty setOrdered: NO];
		
		[collection setPropertyDescriptions: A(collectionContentsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: collection];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: collection
																   forClass: [COCollection class]];
		
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
		assert([[[[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.COGroup"] propertyDescriptionForName: @"contents"] isComposite]);
	}
}

// Attributes

- (ETEntityDescription *)entityDescription
{
	return _entityDescription;
}

- (ETUUID*) UUID
{
	return _uuid;
}

- (COEditingContext*) editingContext
{
	return _context;
}

- (BOOL) isFault
{
	return _isFault;
}

- (BOOL) isDamaged
{
	return _isDamaged; 
}

/* Helper methods based on the metamodel */

- (NSArray*)allStronglyContainedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isComposite])
		{
			id value = [self valueForProperty: [propDesc name]];
			
			assert([propDesc isMultivalued] ==
				   ([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]));
			
			if ([propDesc isMultivalued])
			{
				for (id subvalue in value)
				{
					if ([subvalue isKindOfClass: [COObject class]])
					{
						[result addObject: subvalue];
						[result addObjectsFromArray: [subvalue allStronglyContainedObjects]];
					}
				}
			}
			else
			{
				if ([value isKindOfClass: [COObject class]])
				{
					[result addObject: value];
					[result addObjectsFromArray: [value allStronglyContainedObjects]];
				}
				// Ignore non-COObject objects
			}
		}
	}
	return result;
}



/* Property-value coding */


- (NSArray *)properties
{
	return [[self entityDescription] allPropertyDescriptionNames];
}

- (id) valueForProperty:(NSString *)key
{
	[self willAccessValueForProperty: key];
	id value = [_variableStorage objectForKey: key];
	if (value == [NSNull null])
	{
		return nil;
	}
	return value;
}

+ (BOOL) isPrimitiveCoreObjectValue: (id)value
{  
	return [value isKindOfClass: [NSNumber class]] ||
		[value isKindOfClass: [NSDate class]] ||
		[value isKindOfClass: [NSData class]] ||
		[value isKindOfClass: [NSString class]] ||
		[value isKindOfClass: [COObject class]] ||
		value == nil;
}

+ (BOOL) isCoreObjectValue: (id)value
{
	if ([value isKindOfClass: [NSArray class]] ||
		[value isKindOfClass: [NSSet class]])
	{
		for (id subvalue in value)
		{
			if (![COObject isPrimitiveCoreObjectValue: subvalue])
			{
				return NO;
			}
		}
		return YES;
	}
	else 
	{
		return [COObject isPrimitiveCoreObjectValue: value];
	}
}

- (void)debugCheckValue:(id)value
{
	if ([value isKindOfClass: [NSArray class]] ||
		[value isKindOfClass: [NSSet class]])
	{
		for (id subvalue in value)
		{
			[self debugCheckValue: subvalue];
		}
	}
	else 
	{
		if ([value isKindOfClass: [COObject class]])
		{
			assert([value editingContext] == _context);
		}    
	}
}

- (void) setValue:(id)value forProperty:(NSString*)key
{
	if (![[self properties] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
		return;
	}
	
	[self willChangeValueForProperty: key];

	if (![COObject isCoreObjectValue: value])
	{
		[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	}

	if (nil == value)
	{
		value = [NSNull null];
	}

	// Collections must be mutable
	if ([value isKindOfClass: [NSArray class]]
		|| [value isKindOfClass: [NSSet class]])
	{
		value = [[value mutableCopy] autorelease];
	}
	
	[self debugCheckValue: value];
	
	[_variableStorage setObject: value
						 forKey: key];
		
	[self didChangeValueForProperty: key];
}

- (void) addObject: (id)object forProperty:(NSString*)key
{
	[self willChangeValueForProperty: key];
	
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call addObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	
	// FIXME: add safety checks
	[[self valueForProperty: key] addObject: object];
	
	[self didChangeValueForProperty: key];
}
- (void) insertObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key
{
	[self willChangeValueForProperty: key];
	
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call inesrtObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: add safety checks
	[[self valueForProperty: key] insertObject: object atIndex: index];
	
	
	[self didChangeValueForProperty: key];
}
- (void) removeObject: (id)object forProperty:(NSString*)key
{
	[self willChangeValueForProperty: key];
	
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	
	// FIXME: add safety checks
	[[self valueForProperty: key] removeObject: object];
	
	[self didChangeValueForProperty: key];
}
- (void) removeObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key
{
	[self willChangeValueForProperty: key];
	
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: add safety checks
	[[self valueForProperty: key] insertObject: object atIndex: index];
	
	
	[self didChangeValueForProperty: key];
}

- (void)willAccessValueForProperty:(NSString *)key
{
	[self unfaultIfNeeded];
}
- (void)willChangeValueForProperty:(NSString *)key
{
	[self unfaultIfNeeded];
}
- (void)didChangeValueForProperty:(NSString *)key
{
	[self notifyContextOfDamageIfNeeded];
}

// Overridable Notifications

- (void) awakeFromInsert
{
	// Set up collections
	BOOL wasIgnoringDamage = _isIgnoringDamageNotifications;
	_isIgnoringDamageNotifications = YES;
	
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			id container = [propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set];
			[self setValue: container forProperty: [propDesc name]];
		}
	}
	
	_isIgnoringDamageNotifications = wasIgnoringDamage;
}

- (void) awakeFromFetch
{
	// Debugging check that collections were set up properly
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			Class cls = [propDesc isOrdered] ? [NSMutableArray class] : [NSMutableSet class];
			if (![[self valueForProperty: [propDesc name]] isKindOfClass: cls])
			{
				[NSException raise: NSInternalInconsistencyException format: @"Property %@ of %@ is a collection but was not set up properly", [propDesc name], self];
			}
		}
	}
}
- (void) willTurnIntoFault
{
} 
- (void) didTurnIntoFault
{
}

// NSObject methods

- (NSString*) description
{
	if ([self isFault])
	{
		return [NSString stringWithFormat: @"<Faulted %@ %p UUID=%@>", NSStringFromClass([self class]), self, _uuid];  
	}
	else
	{
		return [NSString stringWithFormat: @"<%@ %p UUID=%@ variableStorage=%@>", NSStringFromClass([self class]), self, _uuid, _variableStorage];  
	}
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COObject class]])
	{
		COObject *other = (COObject*)object;
		if (![[self UUID] isEqual: [other UUID]])
		{
			return NO; 
		}
		for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
		{
			if (![propDesc isDerived])
			{
				id selfValue = [self valueForProperty: [propDesc name]];
				id otherValue = [other valueForProperty: [propDesc name]];
				if (![selfValue isEqual: otherValue])
				{
					return NO; 
				}
			}
		}
		return YES;
	}
	return NO;
}

/**
 * Automatic fine-grained copy
 */
- (id)copyWithZone: (NSZone*)zone
{
	COObject *newObject = [[[self class] alloc] initWithUUID: [ETUUID UUID]
										   entityDescription: _entityDescription
													 context: _context
													 isFault: NO];
									
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if (![propDesc isDerived])
		{
			id value = [self valueForProperty: [propDesc name]];
			if ([propDesc isContainer])
			{
				[newObject setValue: value forProperty: [propDesc name]];  
			}
			else
			{
				// FIXME: need to deep copy collections
				id valuecopy = [value copyWithZone: zone]; 
				[newObject setValue: valuecopy forProperty: [propDesc name]];
				[valuecopy release];
			}
		}
	}
	return newObject;
}

@end


@implementation COObject (Private)

- (void) turnIntoFault
{
	if (!_isFault)
	{
		[self willTurnIntoFault];
		ASSIGN(_variableStorage, nil);
		_isFault = YES;
		[self didTurnIntoFault];
	}
}

- (void) unfaultIfNeeded
{
	if (!_isIgnoringDamageNotifications && _isFault)
	{
		assert(_variableStorage == nil);
		_variableStorage = [[NSMapTable alloc] init];

		[_context loadObject: self];
		_isFault = NO;
		[self awakeFromFetch];
	}
}

- (void) notifyContextOfDamageIfNeeded
{
	if (!_isIgnoringDamageNotifications && !_isDamaged)
	{
		[_context markObjectDamaged: self]; // This will call -setDamaged: YES on us
	}
}

@end


@implementation COObject (PrivateToEditingContext)

// Init/dealloc

- (id) initWithUUID: (ETUUID*)aUUID 
  entityDescription: (ETEntityDescription*)anEntityDescription
			context: (COEditingContext*)aContext
			isFault: (BOOL)isFault
{
	SUPERINIT;
	
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anEntityDescription);
	NILARG_EXCEPTION_TEST(aContext);
	
	ASSIGN(_uuid, aUUID);
	ASSIGN(_entityDescription, anEntityDescription);
	_context = aContext; // weak reference
	_variableStorage = nil;
	_isFault = isFault;
	_isDamaged = NO;
	_isIgnoringDamageNotifications = NO;
	
	if (!_isFault)
	{
		[_context markObjectDamaged: self];
		_variableStorage = [[NSMapTable alloc] init];
		[self awakeFromInsert]; // FIXME: not necessairly
	}
	
	return self;
}

- (void) dealloc
{
	// FIXME: call user hook?
	
	_context = nil;
	DESTROY(_uuid);
	DESTROY(_entityDescription);
	DESTROY(_variableStorage);
	[super dealloc];
}

- (void) setDamaged: (BOOL)isDamaged
{
	_isDamaged = isDamaged; 
}

@end




@implementation COObject (PropertyListImportExport)

static NSArray *COArrayPropertyListForArray(NSArray *array)
{
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity: [array count]];
	for (id value in array)
	{
		if ([value isKindOfClass: [COObject class]])
		{
			value = [(COObject*)value referencePropertyList];
		}
		[newArray addObject: value];
	}
	return newArray;
}

- (NSDictionary*) propertyListForValue: (NSObject*)value
{
	if ([value isKindOfClass: [COObject class]])
	{
		value = [value referencePropertyList];
	}
	else if ([value isKindOfClass: [NSArray class]])
	{
		value = COArrayPropertyListForArray(value);
	}
	else if ([value isKindOfClass: [NSSet class]])
	{
		value = [NSDictionary dictionaryWithObjectsAndKeys:
				 @"unorderedCollection", @"type",
				 COArrayPropertyListForArray([value allObjects]), @"objects",
				 nil];
	}
	else if (value == nil)
	{
		value = [NSDictionary dictionaryWithObject: @"nil" forKey: @"type"];
	}
	return value;
}

- (NSDictionary*) referencePropertyList
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"object-ref", @"type",
			[_uuid stringValue], @"uuid",
			[_entityDescription fullName], @"entity",
			nil];
}

- (NSObject *)valueForPropertyList: (NSObject*)plist
{
	if ([plist isKindOfClass: [NSDictionary class]])
	{
		if ([[plist valueForKey: @"type"] isEqualToString: @"object-ref"])
		{
			ETUUID *uuid = [ETUUID UUIDWithString: [plist valueForKey: @"uuid"]];
			return [[self editingContext] objectWithUUID: uuid 
											  entityName: [plist valueForKey: @"entity"]];
		}
		else if ([[plist valueForKey: @"type"] isEqualToString: @"unorderedCollection"])
		{
			NSArray *objects = [plist valueForKey: @"objects"];
			NSMutableSet *set = [NSMutableSet setWithCapacity: [objects count]];
			for (int i=0; i<[objects count]; i++)
			{
				[set addObject: [self valueForPropertyList: [objects objectAtIndex:i]]];
			}
			return set;
		}
		else if ([[plist valueForKey: @"type"] isEqualToString: @"nil"])
		{
			return nil;
		}
	}
	else if ([plist isKindOfClass: [NSArray class]])
	{
		NSUInteger count = [(NSArray*)plist count];
		id mapped[count];
		for (int i=0; i<count; i++)
		{
			mapped[i] = [self valueForPropertyList: [(NSArray*)plist objectAtIndex:i]];
		}
		return [NSArray arrayWithObjects: mapped count: count];
	}
	return plist;
}

@end


@implementation COObject (Debug)

- (NSString*)detailedDescription
{
	NSMutableString *str = [NSMutableString stringWithFormat: @"%@, object data: {\n", [self description]];
	for (NSString *prop in [self properties])
	{
		[str appendFormat:@"\t'%@' : %@\n", prop, [self valueForProperty: prop]]; 
	}
	[str appendFormat:@"}"];
	return str;
}

@end
