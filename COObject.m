#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "NSData+sha1.h"

@implementation COObject

/**
 * Designated initializer
 */
- (id) initWithModelDescription: (ETEntityDescription*)desc
                        context: (COEditingContext*)ctx
                           uuid: (ETUUID*)uuid
                          isNew: (BOOL)isNew
{
	SUPERINIT;
	
	ASSIGN(_ctx, ctx);
	assert(_ctx != nil);
	
	ASSIGN(_uuid, uuid);
	assert(_uuid != nil);  
	
	_data = nil;
	_isFault = YES;
	
	[_ctx recordObject: self forUUID: [self uuid]];
	
	ASSIGN(_description, desc);
	
	if (nil == [self modelDescription])
	{
		assert(0); // FIXME: remove
		[NSException raise: NSInvalidArgumentException
					format: @"Error, you must either provide a description to -[COObject initWithModelDescription:context:] or have a description registered for the subclass of COObject you are using."];
		return nil;
	}
	
	// FIXME: this is kind of ugly
	// Set up multivalued properties
	for (ETPropertyDescription *propDesc in [[self modelDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			id container = [propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set];
			[self setValue: container forProperty: [propDesc name]];
		}
	}
	
	if (isNew)
	{
		[self awakeFromCreate];
		[self setModified];
	}
	
	return self;
}

- (id) initFaultedObjectWithContext: (COEditingContext*)ctx uuid: (ETUUID*)uuid
{
	[self release];
	
	COStoreCoordinator *sc = [ctx storeCoordinator];
	COHistoryNode *node = [ctx baseHistoryGraphNode];
	NSDictionary *data = [sc dataForObjectWithUUID: uuid
								atHistoryGraphNode: node];
	if (data == nil)
	{
		NSLog(@"Warning, requested object %@ not in store", uuid);
		return nil;
	}
	
	NSString *classname = [data objectForKey: @"class"];
	
	self = [NSClassFromString(classname) alloc];
	self = [super init];
	if (self == nil)
	{
		NSLog(@"Initializing requested class %@ failed, using COObject", classname);
		self = [COObject alloc];
		self = [super init];
		if (self == nil)
		{
			return nil;
		}
	}
    
	ETEntityDescription *desc = [[ETModelDescriptionRepository mainRepository] descriptionForName: [data objectForKey: @"entity"]];
	
	return [self initWithModelDescription: desc
								  context: ctx
									 uuid: uuid
									isNew: NO];
}

/**
 * Create a new object with the given model description in the given context
 */
- (id) initWithModelDescription: (ETEntityDescription*)desc context: (COEditingContext*)ctx
{
	return [self initWithModelDescription: desc
								  context: ctx
									 uuid: [ETUUID UUID]
									isNew: YES];
}

/**
 * Create a new object of the receiver's class in the given context
 */
- (id) initWithContext: (COEditingContext*)ctx
{
	return [self initWithModelDescription:nil context:ctx];
}

- (void) dealloc
{
	DESTROY(_ctx);
	DESTROY(_uuid);
	DESTROY(_data);
	[super dealloc];
}

/**
 * Note, two objects are considered equal if they have the same UUID
 * (even if the instances represent different versions.)
 *
 * This will make diffing just work, but maybe doesn't make sense?
 */
- (BOOL) isEqual: (id)otherObject
{
	if ([otherObject isKindOfClass: [COObject class]])
	{
		COObject *otherCOObject = (COObject*)otherObject;
		return [[otherCOObject uuid] isEqual: _uuid];
	}
	return NO;
}

/**
 * Automatic fine-grained copy
 */
- (id)copyWithZone: (NSZone*)zone
{
	COObject *newObject = [[[self class] alloc] initWithModelDescription: _description context: _ctx];
	for (ETPropertyDescription *propDesc in [[self modelDescription] allPropertyDescriptions])
	{
		if (![propDesc isDerived])
		{
			id value = [self valueForProperty: [propDesc name]];
			if ([propDesc isComposite])
			{
				id valuecopy = [value copyWithZone: zone];
				[newObject setValue: valuecopy forProperty: [propDesc name]];
				[valuecopy release];
			}
			else
			{
				[newObject setValue: value forProperty: [propDesc name]];  
			}
		}
	}
	return newObject;
}

static void GatherAllStronglyContainedObjects(id object, NSMutableArray *dest)
{
	if (![object isKindOfClass: [COObject class]])
	{
		[dest addObject: object];
		return;
	}
}

- (NSArray*)allStronglyContainedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	for (ETPropertyDescription *propDesc in [[self modelDescription] allPropertyDescriptions])
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

- (ETEntityDescription *)modelDescription
{
	if (_description != nil)
	{
		return _description;
	}
	else
	{
		return [[ETModelDescriptionRepository mainRepository]
				entityDescriptionForClass: [self class]];    
	}
}

- (ETUUID*) uuid
{
	return _uuid;
}
- (COEditingContext*) objectContext
{
	return _ctx;
}

- (BOOL) isFault
{
	return _isFault;
}

- (void) didAwaken
{
	// FIXME: remove
	NSLog(@"%@ awoke.", self);
}
- (void) awakeFromCreate
{
	NSLog(@"%@ awoke from create.", self);
}

- (NSArray *)properties
{
	return [[self modelDescription] allPropertyDescriptionNames];
}

- (void)setPrimitiveValue:(id)value forKey:(NSString *)key
{
	[super setValue:value forKey:key];
}

- (id)primitiveValueForKey:(NSString *)key
{
	return [super valueForKey: key]; // Call NSObject's -valueForKey: (we override -valueForKey:)
}

/**
 * If the returned value is an array/set, if it is modified, the context
 * must be notified.
 */
- (id)privateValueForProperty: (NSString*)key
{  
	id result;
	@try
	{
		result = [self primitiveValueForKey: key];
	}
	@catch (NSException *exc)
	{
		result = [_data objectForKey: key];  
	}
	return result;
}

- (id) valueForProperty:(NSString *)key
{
	[self willAccessValueForProperty: key];
	id obj = [self privateValueForProperty: key];
	
	// Make sure we return an immutable collection
	if ([obj isKindOfClass: [NSArray class]])
	{
		return [NSArray arrayWithArray: obj];
	}
	if ([obj isKindOfClass: [NSSet class]])
	{
		return [NSSet setWithSet: obj];
	}
	else
	{
		return obj;
	}
}

+ (BOOL) isPrimitiveCoreObjectValue: (id)value
{  
	return [value isKindOfClass: [NSNumber class]] ||
    [value isKindOfClass: [NSDate class]] ||
    [value isKindOfClass: [NSData class]] ||
    [value isKindOfClass: [NSString class]] ||
    [value isKindOfClass: [COObject class]];
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
			assert([value objectContext] == _ctx);
		}    
	}
}

- (void) privateSetValue:(id)value forProperty:(NSString*)key
{
	if (nil == value)
	{
		// FIXME: Hack
		value = @"<nil>";
		
		//    assert(0);
		//    [NSException raise: NSInvalidArgumentException format: @"Tried to set nil value for property"];
	}
	if (![COObject isCoreObjectValue: value])
	{
		[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	}
	
	if (![[self properties] containsObject: key])
	{
		NSLog(@"Tried to set value for invalid property %@", key);
		return;
	}
	
	// Collections must be mutable
	if ([value isKindOfClass: [NSArray class]]
		|| [value isKindOfClass: [NSSet class]])
	{
		value = [[value mutableCopy] autorelease];
	}
	
	[self debugCheckValue: value];
	
	// FIXME: slow
	@try
	{
		[self setPrimitiveValue:value forKey:key];
	}
	@catch (NSException *e)
	{
		if (nil == _data)
		{
			_data = [[NSMutableDictionary alloc] init];
		}
		[_data setValue: value
				 forKey: key];
	}
}
- (void) setValue:(id)value forProperty:(NSString*)key
{
	[self willChangeValueForKey:key];
	[self privateSetValue:value forProperty:key];
	[self didChangeValueForKey: key];
}

- (NSString*)description
{
	if ([self isFault])
	{
		return [NSString stringWithFormat: @"<Faulted %@ %p UUID=%@>", NSStringFromClass([self class]), self, _uuid];  
	}
	else
	{
		return [NSString stringWithFormat: @"<%@ %p UUID=%@ data=%@>", NSStringFromClass([self class]), self, _uuid, _data];  
	}
}

- (void)willAccessValueForProperty:(NSString *)key
{
	[self loadIfNeeded];
}
- (void)willChangeValueForProperty:(NSString *)key
{
	[self loadIfNeeded];
}
- (void)didChangeValueForProperty:(NSString *)key
{
	[self setModified];
}

- (NSString*)detailedDescription
{
	NSMutableString *str = [NSMutableString stringWithFormat: @"%@, data: {\n", [self description]];
	for (NSString *prop in [self properties])
	{
		[str appendFormat:@"\t'%@' : %@\n", prop, [self valueForProperty: prop]]; 
	}
	[str appendFormat:@"}"];
	return str;
}

@end








@implementation COObject (Private)

- (void) markAsNeedingReload
{
	_isFault = YES;
}

- (void) loadIfNeeded
{
	if ([self isFault])
	{
		[_ctx loadObjectWithDataAtBaseHistoryGraphNode: self];
	}
}

- (void) unload
{
	[_data release];
	_data = nil;
}

/**
 * Returns a sha1 of the object
 */
- (NSData*)sha1Hash
{
	// FIXME : generating the property list and throwing it away is wasteful, remove this method
	
	return [[self propertyList] sha1Hash];
}

- (void) setModified
{
	if (!_isUnfaulting)
	{
		[[self objectContext] markObjectUUIDChanged: [self uuid]];
	}
}

@end



@implementation COObject (Rollback)

/**
 * Reverts back to the last saved version
 */
- (void) revert
{
	// FIXME: revert owned children?
	if ([_ctx objectHasChanges: _uuid])
	{
		[_ctx loadObjectWithDataAtBaseHistoryGraphNode: self];
		[_ctx markObjectUUIDUnchanged: _uuid];
	}
}

/**
 * Commit changes made to jst this object?
 */
- (void) commit
{
	[_ctx commitObjects: [NSArray arrayWithObject: self]];
}

/**
 * Rolls back this object to the state it was in at the given revision, discarding all current changes
 */
- (void) rollbackToRevision: (COHistoryNode *)ver
{
	[_ctx loadObject: self withDataAtHistoryGraphNode: ver];
	[_ctx markObjectUUIDChanged: _uuid];
}

/**
 * Replaces the reciever with the result of doing a three-way merge with it an otherObj,
 * using baseObj as the base revision.
 *
 * Note that otherObj and baseObj will likely be COObject instances represeting the
 * same UUID as the reciever from other (temporary) object contexts
 * constructed just for doing the merge.
 *
 * Note that nothing is committed.
 */
- (void) threeWayMergeWithObject: (COObject*)otherObj base: (COObject *)baseObj
{
	[self loadIfNeeded];
	
	COObjectGraphDiff *oa = [COObjectGraphDiff diffObject: baseObj with: self];
	COObjectGraphDiff *ob = [COObjectGraphDiff diffObject: baseObj with: otherObj];
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	[merged applyToContext: [self objectContext]];
	
	//FIXME: applying |merged| to the context will mutate |baseObj|, not |self|
}

- (void) twoWayMergeWithObject: (COObject *)otherObj
{
	[[self objectContext] twoWayMergeObjects: [NSArray arrayWithObject: self]
								 withObjects: [NSArray arrayWithObject: otherObj]];
}

- (void) selectiveUndoChangesMadeInRevision: (COHistoryNode *)ver
{
	[[self objectContext] selectiveUndoChangesInObjects: [NSArray arrayWithObject: self]
										 madeInRevision: ver];
}

@end



@implementation COObject (PropertyListImportExport)

NSArray *COArrayPropertyListForArray(NSArray *array)
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

- (NSDictionary*) propertyList
{
	[self loadIfNeeded];
	
	NSMutableDictionary *keysAndValues = [NSMutableDictionary dictionary];
	for (id key in [self properties])
	{
		id value = [self valueForProperty: key];
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
		if (value == nil)
		{
			//NSLog(@"Warning, property %@ is nil when generating property list", key);
		}
		else
		{
			[keysAndValues setValue: value forKey: key];
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"object-data", @"type",
			[_uuid stringValue], @"uuid",
			keysAndValues, @"keysAndValues",
			NSStringFromClass([self class]), @"class",
			[[self modelDescription] fullName], @"entity",
			nil];
}

- (NSDictionary*) referencePropertyList
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"object-ref", @"type",
			[_uuid stringValue], @"uuid",
			nil];
}

- (NSObject *)parsePropertyList: (NSObject*)plist
{
	if ([plist isKindOfClass: [NSDictionary class]])
	{
		if ([[plist valueForKey: @"type"] isEqualToString: @"object-ref"])
		{
			ETUUID *uuid = [ETUUID UUIDWithString: [(NSDictionary*)plist objectForKey: @"uuid"]];
			return [[self objectContext] objectForUUID: uuid];
		}
		else if ([[plist valueForKey: @"type"] isEqualToString: @"unorderedCollection"])
		{
			NSArray *objects = [plist valueForKey: @"objects"];
			NSMutableSet *set = [NSMutableSet setWithCapacity: [objects count]];
			for (int i=0; i<[objects count]; i++)
			{
				[set addObject: [self parsePropertyList: [objects objectAtIndex:i]]];
			}
			return set;
		}
	}
	else if ([plist isKindOfClass: [NSArray class]])
	{
		NSUInteger count = [(NSArray*)plist count];
		id mapped[count];
		for (int i=0; i<count; i++)
		{
			mapped[i] = [self parsePropertyList: [(NSArray*)plist objectAtIndex:i]];
		}
		return [NSArray arrayWithObjects: mapped count: count];
	}
	return plist;
}

/**
 * This takes a data dictionary from the store and replaces object references
 * with actual (faulted) COObject instances
 */
- (void)unfaultWithData: (NSDictionary*)data
{
	if (data == nil)
	{
		// We get here when -loadIfNeeded is called on a new object
		// not yet in the store.
		//NSLog(@"ERROR: unfaultWithData: called with nil.. investigate");
		return;
	}
	assert([[data objectForKey:@"uuid"] isEqual: [[self uuid] stringValue]]);
	assert([[data objectForKey:@"type"] isEqual: @"object-data"]);
	assert([[data objectForKey:@"class"] isEqual: NSStringFromClass([self class])]);
	assert([[data objectForKey:@"entity"] isEqual: [[self modelDescription] fullName]]);
	
	_isFault = NO;
	_isUnfaulting = YES;
	assert(![[self objectContext] objectHasChanges: [self uuid]]);
	
	NSDictionary *keysAndValues = [data valueForKey: @"keysAndValues"];
	for (NSString *key in [keysAndValues allKeys])
	{
		assert(![[self objectContext] objectHasChanges: [self uuid]]);
		// NOTE: This must not case change notifications, which is why we call privateSetValue:forProperty:
		[self privateSetValue: [self parsePropertyList: [keysAndValues objectForKey: key]]
				  forProperty: key];
		assert(![[self objectContext] objectHasChanges: [self uuid]]);
	}
	
	[self didAwaken];
	
	assert(![[self objectContext] objectHasChanges: [self uuid]]);
	_isUnfaulting = NO;
}

@end