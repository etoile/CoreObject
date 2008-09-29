/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <strings.h>
#import "COObject.h"
#import "COMultiValue.h"
#import "COObjectContext.h"
#import "NSObject+CoreObject.h"
#import "GNUstep.h"

static NSMutableDictionary *propertyTypes;

/* Properties */
NSString *kCOUIDProperty = @"kCOUIDProperty";
NSString *kCOVersionProperty = @"kCOVersionProperty";
NSString *kCOCreationDateProperty = @"kCOCreationDateProperty";
NSString *kCOModificationDateProperty = @"kCOModificationDateProperty";
NSString *kCOReadOnlyProperty = @"kCOReadOnlyProperty";
 /* Transient property (see -finishedDeserializing) */
NSString *kCOParentsProperty = @"kCOParentsProperty";

NSString *qCOTextContent = @"qCOTextContent";

/* Notifications */
NSString *kCOObjectChangedNotification = @"kCOObjectChangedNotification";
NSString *kCOUpdatedProperty = @"kCOUpdatedProperty";
NSString *kCORemovedProperty = @"kCORemovedProperty";

@interface COObject (FrameworkPrivate)
- (void) setObjectContext: (COObjectContext *)ctxt;
@end

@interface COObject (COPropertyListFormat)
- (void) _readObjectVersion1: (NSDictionary *)propertyList;
- (NSMutableDictionary *) _outputObjectVersion1;
@end

@interface COObject (Private)
- (NSString *) _textContent;
@end


@implementation COObject

/* Data Model Declaration */

/** If you want to create a subclass of a CoreObject data model class, you 
    should declare the new properties and types of the class by creating a 
    dictionary with types as objects and keys as properties, then calls 
    +addPropertiesAndTypes: with this dictionary as parameter.
    Each type must be a NSNumber initialized with one of the type constants 
    defined in COPropertyType.h. Each property must be a string that uniquely 
    identify the property by its name, and whose name doesn't collide with a 
    property inherited from superclasses. For properties, you typically declare 
    your owns as string constants with an identifier name prefixed by 'k' and
    suffixed by 'Property'. For example, see COObject.h which exposes all 
    properties of the COObject data model class.
    When you create a subclass of COObject or some other subclasses such as 
    COGroup, you  must first call +initalize on your superclass to get all 
    inherited properties and types registered for your subclass. This only holds 
    for the GNU runtime though, and may change in future if CoreObject was 
    ported to another runtime. */
+ (void) initialize
{
	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			kCOUIDProperty,
		[NSNumber numberWithInt: kCOIntegerProperty], 
			kCOVersionProperty,
		[NSNumber numberWithInt: kCODateProperty], 
			kCOCreationDateProperty,
		[NSNumber numberWithInt: kCODateProperty], 
			kCOModificationDateProperty,
		[NSNumber numberWithInt: kCOIntegerProperty], 
			kCOReadOnlyProperty,
		[NSNumber numberWithInt: kCOArrayProperty], 
			kCOParentsProperty,
		nil];
	[self addPropertiesAndTypes: pt];
	DESTROY(pt);
}

+ (int) addPropertiesAndTypes: (NSDictionary *) properties
{
	if (propertyTypes == nil)
	{
		propertyTypes = [[NSMutableDictionary alloc] init];
	}

	NSMutableDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		dict = [[NSMutableDictionary alloc] init];
		[propertyTypes setObject: dict forKey: NSStringFromClass([self class])];
		RELEASE(dict);
	}
	int i, count;
	NSArray *allKeys = [properties allKeys];
	NSArray *allValues = [properties allValues];
	count = [allKeys count];
	for (i = 0; i < count; i++)
	{
		[dict setObject: [allValues objectAtIndex: i]
		      forKey: [allKeys objectAtIndex: i]];
	}
	return count;
}

+ (NSDictionary *) propertiesAndTypes
{
	return [propertyTypes objectForKey: NSStringFromClass([self class])];
}

+ (NSArray *) properties
{
	if (propertyTypes == nil)
		return nil;

	NSDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
		return nil;

	return [dict allKeys];
}

+ (int) removeProperties: (NSArray *) properties
{
	if (propertyTypes == nil)
		return 0;
	NSMutableDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		return 0;
	}
	NSEnumerator *e = [properties objectEnumerator];
	NSArray *allKeys = [dict allKeys];
	NSString *key = nil;
	int count = 0;
	while ((key = [e nextObject]))
	{
		if ([allKeys containsObject: key])
		{
			[dict removeObjectForKey: key];
			count++;
		}
	}
	return count;
}

+ (COPropertyType) typeOfProperty: (NSString *) property
{
	if (propertyTypes == nil)
		return kCOErrorInProperty;

	NSDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		return kCOErrorInProperty;
	}

	NSNumber *type = [dict objectForKey: property];
	if (type)
		return [type intValue];
	else
		return kCOErrorInProperty;
}

/* Factory Method */

/** Returns a core object graph by importing propertyList. */
+ (id) objectWithPropertyList: (NSDictionary *) propertyList
{
	id object = nil;
	if ((object = [propertyList objectForKey: pCOClassKey]) &&
	    ([object isKindOfClass: [NSString class]]))
	{
		Class oClass = NSClassFromString((NSString *)object);
		return AUTORELEASE([[oClass alloc] initWithPropertyList: propertyList]);
	}
	return nil;
}

/* Property List Import/Export */

/** <init /> **/
- (id) initWithPropertyList: (NSDictionary *) propertyList
{
	self = [self init];
	if ([propertyList isKindOfClass: [NSDictionary class]] == NO)
	{
		NSLog(@"Error: Not a valid property list: %@", propertyList);
		[self dealloc];
		return nil;
	}
	/* Let check version */
	NSString *v = [propertyList objectForKey: pCOVersionKey];
	if ([v isEqualToString: pCOVersion1Value])
	{
		[self _readObjectVersion1: propertyList];
	}
	else
	{
		NSLog(@"Unknown version %@", v);
		[self dealloc];
		return nil;
	}

	return self;
}

/** Returns the receiver data model as a property list.
    You can use this method for exporting and -initWithPropertyList: as the 
    symetric method for importing. 
    If you want to export an object graph rather than a single object, use 
    -[COGroup propertyList].*/
- (NSMutableDictionary *) propertyList
{
	return [self _outputObjectVersion1];
}

/* Common Methods */

- (id) init
{
	self = [super init];

	_properties = [[NSMutableDictionary alloc] init];
	[self setValue: [NSNumber numberWithInt: 0] 
	      forProperty: kCOReadOnlyProperty];
	[self setValue: [NSString UUIDString]
	      forProperty: kCOUIDProperty];
	[self setValue: [NSNumber numberWithInt: 0]
	      forProperty: kCOVersionProperty];
	[self setValue: [NSDate date]
	      forProperty: kCOCreationDateProperty];
	[self setValue: [NSDate date]
	      forProperty: kCOModificationDateProperty];
    [self setValue: [NSMutableArray array]
          forProperty: kCOParentsProperty]; /* Transient property */
	_nc = [NSNotificationCenter defaultCenter];

	/* We get the object context at the end, hence all the previous calls are 
	   not serialized by RECORD in -setValue:forProperty: 
	   FIXME: Should be obtained by parameter usually. */
	_objectVersion = -1;
	if ([[self class] automaticallyMakeNewInstancesPersistent])
	{
		[[COObjectContext currentContext] registerObject: self];
		[self enablePersistency];
	}

	return self;
}

- (void) dealloc
{
	DESTROY(_properties);
	// NOTE: _objectContext is a weak reference
	
	[super dealloc];
}

// TODO: Turn this into -shortDescription probably and add a more detailed 
// -description that ouputs all the properties. 
// Take note that [_properties description] won't work, because...
// -description triggers -description on kCOParentsProperty and each element 
// is a COGroup instances which will call -description on 
// kCOGroupChildrenProperty and kCOGroupSubgroupsProperty. This will call back 
// -description on the receiver and results in an infinite recursion.
- (NSString *) description
{
	NSString *desc = [super description];

	return [NSString stringWithFormat: @"%@ id: %@ version: %i", desc, 
		[self UUID], [self objectVersion]];
}

- (BOOL) isCoreObject
{
	return YES;
}

- (BOOL) isManagedCoreObject
{
	return YES;
}

- (BOOL) isCopyPromise
{
	return NO;
}

// FIXME: Implement
- (NSDictionary *) metadatas
{
	return nil;
}

/* Managed Object Edition */

/** Returns the properties published by the receiver and accessible through 
	Property Value Coding. The returned array includes the properties inherited 
	from the superclass too (see -[NSObject properties]). */
- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: [[self class] properties]];
}

- (BOOL) removeValueForProperty: (NSString *) property
{
	if (IGNORE_CHANGES || [self isReadOnly])
		return NO;

	RECORD(property)
	[_properties removeObjectForKey: property];
	[self setValue: [NSDate date] forProperty: kCOModificationDateProperty];
    [_nc postNotificationName: kCOObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kCORemovedProperty, nil]];
	END_RECORD

	return YES;
}

- (BOOL) setValue: (id) value forProperty: (NSString *) property
{
	if (IGNORE_CHANGES || [self isReadOnly])
		return NO;

	RECORD(value, property)
	[_properties setObject: value forKey: property];
	[_properties setObject: [NSDate date] 
	                forKey: kCOModificationDateProperty];
    [_nc postNotificationName: kCOObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kCOUpdatedProperty, nil]];
	END_RECORD

	return YES;
}

/** Returns the value identified by property. If the property doesn't exist,
    returns nil.
    First try to find the property in the receiver data model. If no property is 
    found, try to find it in the properties inherited from the superclass. 
    Take note that COObject only inherits properties from NSObject. */
- (id) valueForProperty: (NSString *) property
{
	id value = [_properties objectForKey: property];
	
	/* Pass up to NSObject+Model if not declared in our data model */
	if (value == nil && [[[self class] properties] containsObject: property] == NO)
		value = [super valueForProperty: property];

	return value;
}

- (NSArray *) parentGroups
{
    NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
    NSArray *value = [self valueForProperty: kCOParentsProperty];
    if (value)
    {
        [set addObjectsFromArray: value];

        int i, count = [value count];
        for (i = 0; i < count; i++)
        {
            [set addObjectsFromArray: [[value objectAtIndex: i] parentGroups]];
        }
    }
    return [set allObjects];
}

- (BOOL) isReadOnly
{	
	return ([[self valueForProperty: kCOReadOnlyProperty] intValue] == 1);
}

/** Returns the version of the object format, plays a role similar to class 
    versioning provided by +[NSObject version]. */
- (int) version
{
	return [(NSNumber *)[self valueForProperty: kCOVersionProperty] intValue];
}

/* Persistency */

/** Returns an array of all selectors names whose methods calls can trigger
    persistency, by handing an invocation to the object context which can in  
    turn record it and snapshot the receiver if necessary.
    All messages which are managed method calls are persisted only if necessary, 
    so if such a message is sent by another managed object part of the same 
    object context, it won't be recorded (see COObjectContext for a more 
    thorough explanation). 
    This method plays a no role currently, if we put aside some runtime 
    reflection that could be eventually done with it. In future, by overriding 
    this method, you will be able to declare which methods should automatically 
    triggers persistency without having to rely on RECORD and END_RECORD macros 
    in your method body. */
+ (NSArray *) managedMethodNames
{
	return A(NSStringFromSelector(@selector(setValue:forProperty:)),
	         NSStringFromSelector(@selector(removeValueForProperty:)));
}

static NSMutableSet *automaticPersistentClasses = nil;

/** Returns whether the instances, that are member of this specific class, are 
    made persistent when they are initialized. */
+ (BOOL) automaticallyMakeNewInstancesPersistent
{
	return [automaticPersistentClasses containsObject: self];
}

/** Sets whether the instances, that are member of this specific class, are 
    made persistent when they are initialized. 
    An instance becomes persistenty by registering it in an object context and 
    sending it -enablePersistency. */
+ (void) setAutomaticallyMakeNewInstancesPersistent: (BOOL)flag
{
	if (automaticPersistentClasses == nil)
		automaticPersistentClasses = [[NSMutableSet alloc] init];

	if (flag)
	{
		[automaticPersistentClasses addObject: self];
	}
	else
	{
		[automaticPersistentClasses removeObject: self];
	}
}

/** Allows to temporarily disable persistency for the receiver. 
    All managed method calls will not result in any recorded invocations or 
    snapshots.
    A very common usage of this method is to avoid the recording of 
    initialization messages in -init. For example:
    SUPERINIT
    [self disablePersistency]; // was enabled by the superclass (such as COObject)
    [self setValue: @"Swansea forProperty: @"Town"];
    [self enablePersistency];
    return self;
    An object will continue to return YES for -isPersistent, even if 
   -disablePersistency has been called. */
- (void) disablePersistency
{
	if ([self objectContext] == nil)
	{
		//ETLog(@"WARNING: %@ misses an object context to disable persistency", self);
	}

	// NOTE: Another way would be: [_objectContext unregisterObject: self];
	// By doing, we wouldn't need to check explictly for _isPersistencyEnabled 
	// in RECORD macro and the object context would discard the invocation 
	// because the receiver isn't registered. However testing whether the 
	// persistency is enabled makes sense, because invocations are created 
	// only if needed.
	// _isPersistencyEnabled would be easy to replace by -isPersistencyEnabled 
	// { return [[_objectContext registeredObjects] containsObject: self] }
	_isPersistencyEnabled = NO;
}

/** Allows to restore persistency for the receiver, if it is presently
    disabled. See -disablePersistency. */
- (void) enablePersistency
{
	if ([self objectContext] == nil)
	{
		//ETLog(@"WARNING: %@ misses an object context to enable persistency", self);
	}
	
	// NOTE: Another way would be: [_objectContext registerObject: self];
	_isPersistencyEnabled = YES;
}

/** Returns whether the receiver has been turned into a persistent object. 
    Once an object has become persistent, it will remain so until it got 
    fully destroyed:
    - deallocated in memory
    - deleted on-disk
   TODO: Add the possibility to create a non-persistent copy from a persistent
   instance. */
- (BOOL) isPersistent
{
	return ([self objectVersion] > -1);
}

- (COObjectContext *) objectContext
{
	return _objectContext;
}

- (void) setObjectContext: (COObjectContext *)ctxt
{
	/* The object context is our owner and retains us. */
	_objectContext = ctxt;
}

- (void) _setObjectVersion: (int)version
{
	ETDebugLog(@"Setting version from %d to %d of %@", _objectVersion, version, self);
	_objectVersion = version;
}

/** Returns the current version of the instance. This version represents a 
    revision in the object history. 
    The returned value is comprised between 0 (base version created on first 
    serialization) and the last object version which can be known by calling 
    -lastObjectVersion. */
- (int) objectVersion
{
	return _objectVersion;
}

/** API only used for replacing an existing object by a past temporal in the 
    managed object graph. See COObjectContext. 
    WARNING: May be removed later. */
- (int) lastObjectVersion
{
	ETLog(@"Requested last object version, found %d in %@", 
		[_objectContext lastVersionOfObject: self], _objectContext);

	return [_objectContext lastVersionOfObject: self];
	// NOTE: An implementation variant that may prove be quicker would be...
	// return [[COObjectServer objectForUUID: [self UUID]] objectVersion]
	//
	// All managed objects cached in the object server have always 
	// -objectVersion equal to -lastObjectVersion, only temporal instances 
	// break this rule, but temporal instances are never referenced by the 
	// object server. If they are merged, then their object version is 
	// updated to match the one of the object they replace. At this point, 
	// they will be cached in the object server, but not qualify as temporal
	// instances anymore.
}

/** Saves the receiver by asking the object context to make a new snapshot.
    If the save succeeds, returns YES. If the save fails, NO is returned and 
    the object version isn't touched. */
- (BOOL) save
{
	int prevVersion = [self objectVersion];
	[[self objectContext] snapshotObject: self];
	return ([self objectVersion] > prevVersion);
}

/* Identity */

// TODO: Modify COObject to only rely on it and removes -uniqueID
- (ETUUID *) UUID
{
	return AUTORELEASE([[ETUUID alloc] initWithString: [self valueForProperty: kCOUIDProperty]]);
}

/** Returns a hash based on the UUID. */
- (unsigned int) hash
{
	return [[self valueForProperty: kCOUIDProperty] hash];
}

/** Returns whether other is equal the receiver.
    Two managed core objects are equal if they share the same UUID and object 
    version. 
    See also -isTemporalInstance:. */
- (BOOL) isEqual: (id)other
{
	if (other == nil || [other isKindOfClass: [self class]] == NO)
		return NO;

	BOOL hasEqualUUID = [[self valueForProperty: kCOUIDProperty] isEqual: [other valueForProperty: kCOUIDProperty]];
	BOOL hasEqualObjectVersion = ([self objectVersion] == [other objectVersion]);

	return hasEqualUUID && hasEqualObjectVersion;
}

/** Returns whether other is a temporal instance of the receiver.
    Two objects are temporal instances of each other if they share the same 
    UUID but differs by their object version. */
- (BOOL) isTemporalInstance: (id)other
{
	if (other == nil || [other isKindOfClass: [self class]] == NO)
		return NO;

	BOOL hasEqualUUID = [[self valueForProperty: kCOUIDProperty] isEqual: [other valueForProperty: kCOUIDProperty]];
	BOOL hasDifferentObjectVersion = ([self objectVersion] != [other objectVersion]);

	return hasEqualUUID && hasDifferentObjectVersion;
}

/* Query */

/** See COObject protocol. */
- (BOOL) matchesPredicate: (NSPredicate *)aPredicate
{
	BOOL result = NO;
	if ([aPredicate isKindOfClass: [NSCompoundPredicate class]])
	{
		NSCompoundPredicate *cp = (NSCompoundPredicate *)aPredicate;
		NSArray *subs = [cp subpredicates];
		int i, count = [subs count];
		switch ([cp compoundPredicateType])
		{
			case NSNotPredicateType:
				result = ![self matchesPredicate: [subs objectAtIndex: 0]];
				break;
			case NSAndPredicateType:
				result = YES;
				for (i = 0; i < count; i++)
				{
					result = result && [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			case NSOrPredicateType:
				result = NO;
				for (i = 0; i < count; i++)
				{
					result = result || [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			default: 
				ETLog(@"Error: Unknown compound predicate type");
		}
	}
	else if ([aPredicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSComparisonPredicate *cp = (NSComparisonPredicate *)aPredicate;
		id lv = [[cp leftExpression] expressionValueWithObject: self context: nil];
		id rv = [[cp rightExpression] expressionValueWithObject: self context: nil];
		NSArray *array = nil;
		if ([lv isKindOfClass: [NSArray class]] == NO)
		{
			array = [NSArray arrayWithObjects: lv, nil];
		}
		else
		{
			array = (NSArray *) lv;
		}
		NSEnumerator *e = [array objectEnumerator];
		id v = nil;
		while ((v = [e nextObject]))
		{
			switch ([cp predicateOperatorType])
			{
				case NSLessThanPredicateOperatorType:
					return ([v compare: rv] == NSOrderedAscending);
				case NSLessThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedDescending);
				case NSGreaterThanPredicateOperatorType:
				return ([v compare: rv] == NSOrderedDescending);
				case NSGreaterThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedAscending);
				case NSEqualToPredicateOperatorType:
					return [v isEqual: rv];
				case NSNotEqualToPredicateOperatorType:
					return ![v isEqual: rv];
				case NSMatchesPredicateOperatorType:
					{
						// FIXME: regular expression
						return NO;
					}
				case NSLikePredicateOperatorType:
					{
						// FIXME: simple regular expression
						return NO;
					}
				case NSBeginsWithPredicateOperatorType:
					return [[v description] hasPrefix: [rv description]];
				case NSEndsWithPredicateOperatorType:
					return [[v description] hasSuffix: [rv description]];
				case NSInPredicateOperatorType:
					// NOTE: it is the reverse CONTAINS
					return ([[rv description] rangeOfString: [v description]].location != NSNotFound);;
				case NSCustomSelectorPredicateOperatorType:
					{
						// FIXME: use NSInvocation
						return NO;
					}
				default:
					ETLog(@"Error: Unknown predicate operator");
			}
		}
	}
	return result;
}

/* Serialization (EtoileSerialize) */

/** If you override this method, you must call superclass implemention before 
    your own code. */
- (BOOL) serialize: (char *)aVariable using: (ETSerializer *)aSerializer
{
	//ETDebugLog(@"Try serialize %s in %@", aVariable, self);
	if (strcmp(aVariable, "_nc") == 0
	 || strcmp(aVariable, "_objectContext") == 0
	 || strcmp(aVariable, "_objectVersion") == 0
	 || strcmp(aVariable, "_isPersistencyEnabled") == 0)
	{
		return YES; /* Should not be automatically serialized (manual) */
	}
	if (strcmp(aVariable, "_properties") == 0)
	{
		/* We discard the parents array which is transient and may have become 
		   invalid. For example, a parent group might have been deleted. 
		   The most important issue is that we are unable to treat a 
		   relationship change, that alter two different objects as an atomic 
		   unit of change. This would imply to serialize/deserialize two 
		   invocations, in a single transaction that binds the two new object 
		   versions (in the history of each object).
		   Moreover...
		   Deserializing all child objects to correct their parent relationships, 
		   would be really slow, if the group has several hundreds of children 
		   or more. Add, remove operations would also be slow on a huge number 
		   of objects, because this would involve to deserialize/reserialize 
		   each moved object.
		   We could alternatively discard kCOParentsProperty on deserialization 
		   rather than at serialization time. */
		// TODO: Benchmark persistentProperties creation cost. If this is too 
		// slow, cache, optimize or eventually turn kCOParentsProperty into 
		// a transient ivar... or some other clever trick.
		// peristentProperties is also fragile currently because it relies 
		// on the assumption that no other autorelease pools is created within 
		// the serialization triggered by -[ETSerializer serializeObject:withName:]
		NSMutableDictionary *persistentProperties = 
			[[NSMutableDictionary alloc] initWithDictionary: _properties];
		[persistentProperties setObject: [NSMutableArray array] forKey: kCOParentsProperty];
		[aSerializer storeObjectFromAddress: &persistentProperties withName: "_properties"];
		AUTORELEASE(persistentProperties);
		return YES;
	}

	return NO; /* Serializer handles the ivar */
}

/** If you override this method, you must call superclass implemention before 
    your own code. */
- (void *) deserialize: (char *)aVariable 
           fromPointer: (void *)aBlob 
               version: (int)aVersion
{
	//ETDebugLog(@"Try deserialize %s into %@ (class version %d)", aVariable, aVersion, self);

	return AUTO_DESERIALIZE;
}

// TODO: If we can get the deserializer in parameter, the next method 
// -deserializerDidFinish:forVersion: might eventually be removed.
/** If you override this method, you must call superclass implemention before 
    your own code. */
- (void) finishedDeserializing
{
	ETDebugLog(@"Finished deserializing of %@", self);

	_nc = [NSNotificationCenter defaultCenter];
	_objectContext = nil;
	 /* Reset a default version to be immediately overriden by
	   deserializerDidFinish:forVersion: called back by the context. 
	   This is also useful to ensure consistency if a non-persistent object is 
	   serialized/deserialized without COObjectContext facility. 
	   See TestSerializer.m */
	_objectVersion = -1;
	/* If we deserialize an object, it is persistent :-) */
	_isPersistencyEnabled = YES;
	// TODO: _properties is an invalid dictionary when this method is called.
	// The next line results in a crash in EtoileSerialize. May be we should 
	// improve EtoileSerialize to push back -finishedDeserializing to a point 
	// where all objects are fully deserialized...
	// This line should be removed later, we now handle kCOParentsProperty as 
	// transient in -serialize:using.
	//[_properties setObject: [NSMutableArray array] forKey: kCOParentsProperty];
}

- (void) deserializerDidFinish: (ETDeserializer *)deserializer forVersion: (int)objectVersion
{
	ETDebugLog(@"Finished deserialization of %@ to object version %d", self, objectVersion);
	_objectVersion = objectVersion;
}

- (void) serializerDidFinish: (ETSerializer *)serializer forVersion: (int)objectVersion
{
	_objectVersion = objectVersion;
}

/* Copying */

- (id) copyWithZone: (NSZone *) zone
{
	COObject *clone = [[[self class] allocWithZone: zone] init];
	clone->_properties = [_properties mutableCopyWithZone: zone];
	return clone;
}

/* KVC */

/** Returns the value identified by key. 
    The returned value is identical to -valueForProperty:, except that it 
    returns the text content if you pass qCOTextContent as key. This addition 
    is used by -matchesPredicate:.
    For now, this method returns nil for an undefined key and doesn't raise an 
    exception by calling -valueForUndefinedKey:, however this is subject to 
    change.*/
- (id) valueForKey: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qCOTextContent])
	{
		return [self _textContent];
	}
	return [self valueForProperty: key];
}

- (id) valueForKeyPath: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qCOTextContent])
	{
		return [self _textContent];
	}

	NSArray *keys = [key componentsSeparatedByString: @"."];
	if ([keys count])
	{
		id value = [self valueForProperty: [keys objectAtIndex: 0]];
		if ([value isKindOfClass: [COMultiValue class]])
		{
			COMultiValue *mv = (COMultiValue *) value;
			int i, count = [mv count];
			NSMutableArray *array = [[NSMutableArray alloc] init];
			if ([keys count] > 1)
			{
				/* Find the label first */
				NSString *label = [keys objectAtIndex: 1];
				for (i = 0; i < count; i++)
				{
					if ([[mv labelAtIndex: i] isEqualToString: label])
					{
						[array addObject: [mv valueAtIndex: i]];
					}
				}
			}
			else
			{
				/* Search all labels */
				for (i = 0; i < count; i++)
				{
					[array addObject: [mv valueAtIndex: i]];
				}
			}
			return AUTORELEASE(array);
		}
	}
	return [self valueForKey: key];
}

/* Return all text for search */
- (NSString *) _textContent
{
	NSMutableString *text = [[NSMutableString alloc] init];
	NSEnumerator *e = [[[self class] properties] objectEnumerator];
	NSString *property = nil;
	while ((property = [e nextObject]))
	{
		COPropertyType type = [[self class] typeOfProperty: property];
		switch(type)
		{
			case kCOStringProperty:
			case kCOArrayProperty:
			case kCODictionaryProperty:
				[text appendFormat: @"%@ ", [[self valueForProperty: property] description]];
				break;
			case kCOMultiStringProperty:
			case kCOMultiArrayProperty:
			case kCOMultiDictionaryProperty:
				{
					COMultiValue *mv = [self valueForProperty: property];
					int i, count = [mv count];
					for (i = 0; i < count; i++)
					{
						[text appendFormat: @"%@ ", [[mv valueAtIndex: i] description]];
					}
				}
				break;
			default:
				continue;
		}
	}
	return AUTORELEASE(text);
}

/* Deprecated */

- (NSString *) uniqueID
{
	return [self valueForProperty: kCOUIDProperty];
}

@end
