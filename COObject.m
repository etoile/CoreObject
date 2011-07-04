#import "COObject.h"
#import "COEditingContext.h"
#import "COContainer.h"
#import "COCollection.h"

@implementation COObject

+ (void)initialize
{
	if (self == [COObject class])
	{
		// COObject entity description
		
		ETEntityDescription *object = [ETEntityDescription descriptionWithName: @"COObject"];
		
		ETPropertyDescription *parentContainerProperty = [ETPropertyDescription descriptionWithName: @"parentContainer"
																						   type: (id)@"Anonymous.COContainer"];
		[parentContainerProperty setIsContainer: YES];
		[parentContainerProperty setMultivalued: NO];
	
		ETPropertyDescription *parentCollectionsProperty = [ETPropertyDescription descriptionWithName: @"parentCollections"
																								type: (id)@"Anonymous.COCollection"];
		
		[parentCollectionsProperty setMultivalued: YES];
		
		[object setPropertyDescriptions: A(parentContainerProperty, parentCollectionsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: object];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: object
																   forClass: [COObject class]];
		
		// COContainer entity description
		
		ETEntityDescription *group = [ETEntityDescription descriptionWithName: @"COContainer"];
		[group setParent: (id)@"Anonymous.COObject"];
		
		ETPropertyDescription *groupContentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																						type: (id)@"Anonymous.COObject"];
		[groupContentsProperty setMultivalued: YES];
		[groupContentsProperty setOpposite: (id)@"Anonymous.COObject.parentContainer"]; // FIXME: just 'parent' should work...
		[groupContentsProperty setOrdered: YES];
		
		[group setPropertyDescriptions: A(groupContentsProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: group];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: group
																   forClass: [COContainer class]];
		
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
		assert([[[[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.COContainer"] propertyDescriptionForName: @"contents"] isComposite]);
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

- (BOOL) isRoot
{
	return _isRoot;
}

- (BOOL) isFault
{
	return _isFault;
}

- (BOOL) isDamaged
{
	return [_context objectHasChanges: _uuid]; 
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

- (NSArray*)allStronglyContainedObjectsIncludingSelf
{
	return [[self allStronglyContainedObjects] arrayByAddingObject: self];
}

/* Property-value coding */


- (NSArray *)propertyNames
{
	return [[self entityDescription] allPropertyDescriptionNames];
}

- (id) valueForProperty:(NSString *)key
{
	[self willAccessValueForProperty: key];
	
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to get value for invalid property %@", key];
		return nil;
	}
	
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

- (BOOL) setValue:(id)value forProperty:(NSString*)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
		return NO;
	}

	if (![COObject isCoreObjectValue: value])
	{
		[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	}

	// FIXME: use the metamodel's validation support?
	
	
	// Begin relationship integrity
	if (!_isIgnoringRelationshipConsistency)
	{	
		[self setIgnoringRelationshipConsistency: YES]; // Needed to guard against recursion
		
		ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
		assert(desc != nil);
		
		if ([desc opposite] != nil)
		{
			NSString *oppositeName = [[desc opposite] name];
			if (![desc isMultivalued]) // modifying the single-valued side of a relationship
			{
				COObject *oldContainer = [self valueForProperty: key];
				COObject *newContainer = value;
				
				if (newContainer != oldContainer)
				{					
					[oldContainer setIgnoringRelationshipConsistency: YES];
					[newContainer setIgnoringRelationshipConsistency: YES];			
					
					if ([[desc opposite] isMultivalued])
					{
						[oldContainer removeObject: self forProperty: oppositeName];
						[newContainer addObject: self forProperty: oppositeName];			
					}
					else
					{
						[oldContainer setValue: nil forProperty: oppositeName];
						[newContainer setValue: self forProperty: oppositeName];			
					}

					[oldContainer setIgnoringRelationshipConsistency: NO];
					[newContainer setIgnoringRelationshipConsistency: NO];
				}
			}
			else // modifying the multivalued side of a relationship
			{
				NSMutableSet *oldObjects;
				if ([[self valueForProperty: key] isKindOfClass: [NSSet class]])
				{
					oldObjects = [NSMutableSet setWithSet: [self valueForProperty: key]];
				}			
				else if ([self valueForProperty: key] == nil)
				{
					oldObjects = [NSMutableSet set]; // Should only happen when an object is first created..
				}
				else
				{
					oldObjects = [NSMutableSet setWithArray: [self valueForProperty: key]];
				}
				
				NSMutableSet *newObjects;
				if ([value isKindOfClass: [NSSet class]])
				{
					newObjects = [NSMutableSet setWithSet: value];
				}
				else
				{
					newObjects = [NSMutableSet setWithArray: value];
				}
				
				NSMutableSet *commonObjects = [NSMutableSet setWithSet: oldObjects];
				[commonObjects intersectSet: newObjects];
				
				[oldObjects minusSet: commonObjects]; 
				[newObjects minusSet: commonObjects];
				// Now newObjects is added objects, and oldObjects is removed objects
				
				for (COObject *obj in [oldObjects setByAddingObjectsFromSet: newObjects])
				{
					[obj setIgnoringRelationshipConsistency: YES];
				}
				
				if ([[desc opposite] isMultivalued])
				{
					for (COObject *oldObj in oldObjects)
					{
						[oldObj removeObject: self forProperty: oppositeName];
					}
					for (COObject *newObj in newObjects)
					{
						[newObj addObject: self forProperty: oppositeName];
					}
				}
				else
				{
					for (COObject *oldObj in oldObjects)
					{
						[oldObj setValue: nil forProperty: oppositeName];
					}
					for (COObject *newObj in newObjects)
					{
						[[newObj valueForProperty: oppositeName] removeObject: newObj forProperty: key];
						[newObj setValue: self forProperty: oppositeName];
					}	
				}

				for (COObject *obj in [oldObjects setByAddingObjectsFromSet: newObjects])
				{
					[obj setIgnoringRelationshipConsistency: NO];
				}
			}
		}
		[self setIgnoringRelationshipConsistency: NO];
	}
	// End relationship integrity	
	
	
	// Collections must be mutable
	if ([value isKindOfClass: [NSArray class]]
		|| [value isKindOfClass: [NSSet class]])
	{
		value = [[value mutableCopy] autorelease];
	}
	
	// Make sure the value is in the same context as us
	[self debugCheckValue: value];
	
	// Actually set the value.
	
	[self willChangeValueForProperty: key];
	
	if (nil == value) { value = [NSNull null]; }
	[_variableStorage setObject: value
						 forKey: key];
		
	[self didChangeValueForProperty: key];

	return YES;
}

- (void) addObject: (id)object forProperty:(NSString*)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call addObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	// FIXME: Modify the value directly.. this will require refactoring setValue:forProperty:
	// so that we can run the relationship integrity code and other checks directly
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]] || [copy isKindOfClass: [NSMutableSet class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy addObject: object];
	[self setValue: copy forProperty: key];
	[copy release];
}
- (void) insertObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call inesrtObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy insertObject: object atIndex: index];
	[self setValue: copy forProperty: key];
	[copy release];
}
- (void) removeObject: (id)object forProperty:(NSString*)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]] || [copy isKindOfClass: [NSMutableSet class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	[copy removeObject: object];
	[self setValue: copy forProperty: key];
	[copy release];
}
- (void) removeObject: (id)object atIndex: (NSUInteger)index forProperty:(NSString*)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy removeObject: object atIndex: index hint: nil];
	[self setValue: copy forProperty: key];
	[copy release];
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
	[self notifyContextOfDamageIfNeededForProperty: key];
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
	if (_inDescription)
	{
		// If we are called recursively, don't print the contents of _variableStorage
		// since it would result in an infinite loop.
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	}
	
	_inDescription = YES;
	NSString *desc;
	if ([self isFault])
	{
		desc = [NSString stringWithFormat: @"<Faulted %@(%@) %p UUID=%@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];  
	}
	else
	{
		desc = [NSString stringWithFormat: @"<%@(%@) %p UUID=%@ properties=%@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid, [self propertyNames]];  
	}
	_inDescription = NO;
	return desc;
}

- (NSUInteger)hash
{
	return [_uuid hash] ^ 0x39ab6f39b15233de;
}

- (BOOL)isEqual: (id)object
{
	if (object == self)
	{
		return YES;
	}
	if (![object isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[object UUID] isEqual: [self UUID]])
	{
		return YES;
	}
	
	return NO;
	/*

	// FIXME: Incomplete/ incorrect
	
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
				if (selfValue == otherValue)
				{
					continue;
				}
				if (![selfValue isEqual: otherValue] && !(selfValue == nil && otherValue == nil))
				{
					return NO; 
				}
			}
		}
		return YES;
	}
	return NO;*/
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

- (void) notifyContextOfDamageIfNeededForProperty: (NSString*)prop
{
	if (!_isIgnoringDamageNotifications)
	{
		[_context markObjectDamaged: self forProperty: prop];
	}
}

- (BOOL) isIgnoringRelationshipConsistency
{
	return _isIgnoringRelationshipConsistency;
}

- (void) setIgnoringRelationshipConsistency: (BOOL)ignore
{
	_isIgnoringRelationshipConsistency = ignore;
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
	_isIgnoringDamageNotifications = NO;
	
	if (!_isFault)
	{
		[_context markObjectDamaged: self forProperty: nil];
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

- (NSDictionary*) propertyListForValue: (id)value
{
	NSDictionary *result = nil;

	if ([value isKindOfClass: [COObject class]])
	{
		result = [value referencePropertyList];
	}
	else if ([value isKindOfClass: [NSArray class]])
	{
		result = (NSDictionary *)COArrayPropertyListForArray(value);
	}
	else if ([value isKindOfClass: [NSSet class]])
	{
		result = [NSDictionary dictionaryWithObjectsAndKeys:
				 @"unorderedCollection", @"type",
				 COArrayPropertyListForArray([value allObjects]), @"objects",
				 nil];
	}
	else if (value == nil)
	{
		result = [NSDictionary dictionaryWithObject: @"nil" forKey: @"type"];
	}
	else if ([COObject isPrimitiveCoreObjectValue: value])
	{
		result = D(value, @"value", @"primitive", @"type");
	}
	else
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"value must of type COObject, NSArray, NSSet or nil"];
		return nil;
	}
	return result;
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
		else if ([[plist valueForKey: @"type"] isEqualToString: @"primitive"])
		{
			return [plist valueForKey: @"value"];
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

static int indent = 0;

- (NSString*)detailedDescription
{
	if (_inDescription)
	{
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	}
	_inDescription = YES;
	indent++;
	NSMutableString *str = [NSMutableString stringWithFormat: @"<%@(%@) at %p UUID %@ data: {\n",  [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	indent++;
	
	NSMutableArray *props = [NSMutableArray arrayWithArray: [self propertyNames]];
	if ([props containsObject: @"contents"])
	{
		[props removeObject: @"contents"];
		[props insertObject: @"contents" atIndex: 0];
	}
	if ([props containsObject: @"label"])
	{
		[props removeObject: @"label"];
		[props insertObject: @"label" atIndex: 0];
	}
	for (NSString *prop in props)
	{
		NSMutableString *valuestring = [NSMutableString string];
		id value = [self valueForProperty: prop];
		if ([value isKindOfClass: [NSSet class]])
		{
			[valuestring appendFormat: @"(\n"];
			for (id item in value)
			{
				for (int i=0; i<indent + 1; i++) [valuestring appendFormat: @"\t"];
				[valuestring appendFormat: @"%@\n", [item description]];	
			}
			for (int i=0; i<indent; i++) [valuestring appendFormat: @"\t"];
			[valuestring appendFormat: @"),\n"];
		}
		else if ([value isKindOfClass: [NSArray class]])
		{
			[valuestring appendFormat: @"{\n"];
			for (id item in value)
			{
				for (int i=0; i<indent + 1; i++) [valuestring appendFormat: @"\t"];
				[valuestring appendFormat: @"%@", [item description]];	
			}
			for (int i=0; i<indent; i++) [valuestring appendFormat: @"\t"];
			[valuestring appendFormat: @"},\n"];
		}
		else
		{
			[valuestring appendFormat: @"%@,\n", [value description]];
		}

		
		for (int i=0; i<indent; i++) [str appendFormat: @"\t"];
		[str appendFormat:@"%@ : %@", prop, valuestring]; 
	}
	indent--;
	for (int i=0; i<indent; i++) [str appendFormat: @"\t"];
	[str appendFormat:@"}>\n"];
	indent--;
	_inDescription = NO;
	return str;
}

@end
