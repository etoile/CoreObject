/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)

	COObjectMatching protocol concrete implementation is based on MIT-licensed 
	code by Yen-Ju Chen <yjchenx gmail> from the previous CoreObject.
 */

#import "COObject.h"
#import "COError.h"
#import "COFault.h"
#import "COPersistentRoot.h"
#import "COStore.h"
#import "COContainer.h"
#import "COGroup.h"
#include <objc/runtime.h>

@implementation COObject

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [COObject className]] == NO) 
		return object;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COObject"
	                               description: @"Core Object"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[object setLocalizedDescription: _(@"Basic Object")];

	ETPropertyDescription *nameProperty = 
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"Anonymous.NSString"];
	// TODO: Declare as a transient property... ETLayoutItem overrides it to be 
	// a persistent property.
	//ETPropertyDescription *idProperty = 
	//	[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *modificationDateProperty = 
		[ETPropertyDescription descriptionWithName: @"modificationDate" type: (id)@"Anonymous.NSDate"];
	ETPropertyDescription *creationDateProperty = 
		[ETPropertyDescription descriptionWithName: @"creationDate" type: (id)@"Anonymous.NSDate"];
	ETPropertyDescription *lastVersionDescProperty = 
		[ETPropertyDescription descriptionWithName: @"lastVersionDescription" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *tagDescProperty = 
		[ETPropertyDescription descriptionWithName: @"tagDescription" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *typeDescProperty = 
		[ETPropertyDescription descriptionWithName: @"typeDescription" type: (id)@"Anonymous.NSString"];

	// TODO: Figure out how to compute and present each core object size...
	// Possible choices would be:
	// - a raw size including the object history data
	// - a snapshot size (excluding the history data)
	// - a directory or file size to be expected if the object is exported

	// TODO: Move these properties to EtoileFoundation... See -[NSObject propertyNames].
	// We should create a NSObject entity description and use it as our parent entity probably.
#ifndef GNUSTEP // We don't link NSImage on GNUstep because AppKit won't work
	ETPropertyDescription *iconProperty = 
		[ETPropertyDescription descriptionWithName: @"icon" type: (id)@"Anonymous.NSImage"];
#endif // GNUSTEP
	ETPropertyDescription *displayNameProperty = 
		[ETPropertyDescription descriptionWithName: @"displayName" type: (id)@"Anonymous.NSString"];

	ETPropertyDescription *tagsProperty = 
		[ETPropertyDescription descriptionWithName: @"tags" type: (id)@"Anonymous.COTag"];
	[tagsProperty setMultivalued: YES];

	NSArray *transientProperties = A(displayNameProperty, modificationDateProperty, 
		creationDateProperty, lastVersionDescProperty, tagDescProperty, typeDescProperty);
#ifndef GNUSTEP
	transientProperties = [transientProperties arrayByAddingObject: iconProperty];
#endif
	NSArray *persistentProperties = A(nameProperty, tagsProperty);

	[[persistentProperties mappedCollection] setPersistent: YES];
	[object setPropertyDescriptions: [transientProperties arrayByAddingObjectsFromArray: persistentProperties]];

	return object;
}

- (NSMapTable *)newVariableStorage
{
	return [[NSMapTable alloc] initWithKeyOptions: NSMapTableStrongMemory 
	                                 valueOptions: NSMapTableStrongMemory 
	                                    capacity: 20];
}

/* Puts mutable collections into multivalued properties. */
- (void)didCreate
{
	BOOL wasIgnoringDamage = _isIgnoringDamageNotifications;
	_isIgnoringDamageNotifications = YES;
	
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			id container = ([propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set]);
			[self setValue: container forProperty: [propDesc name]];
		}
	}
	
	_isIgnoringDamageNotifications = wasIgnoringDamage;
}

- (id) commonInitWithUUID: (ETUUID *)aUUID 
        entityDescription: (ETEntityDescription *)anEntityDescription
                  context: (COPersistentRoot *)aContext
                  isFault: (BOOL)isFault
{
	NSParameterAssert(aUUID != nil);
	BOOL isPersistent = (aContext != nil);
	if (isPersistent)
	{
		NSParameterAssert(anEntityDescription != nil);
	}
	else
	{
		NSParameterAssert(aContext == nil);
	}

	ASSIGN(_uuid, aUUID);
	if (anEntityDescription != nil)
	{
		ASSIGN(_entityDescription, anEntityDescription);
	}
	else
	{
		// NOTE: Ensure we can use -propertyNames and metamodel-based 
		// introspection before -becomePersistentInContext: is called.
		// TODO: Could be removed if -propertyNames in NSObject(Model) do a 
		// lookup in the main repository.
		ASSIGN(_entityDescription, [[ETModelDescriptionRepository mainRepository] 
			entityDescriptionForClass: [self class]]);
	}
	_variableStorage = nil;
	_isIgnoringDamageNotifications = NO;
	_isInitialized = YES;

	if (isFault)
	{
		object_setClass(self, [[self class] faultClass]);
		_persistentRoot = aContext;
	}
	else
	{
		[(id)_persistentRoot markObjectUpdated: self forProperty: nil];
		_variableStorage = [self newVariableStorage];
		[self didCreate];
	}

	return self;
}

- (id)initWithUUID: (ETUUID *)aUUID 
 entityDescription: (ETEntityDescription *)anEntityDescription
           context: (COPersistentRoot *)aContext
           isFault: (BOOL)isFault
{
	SUPERINIT;
	
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anEntityDescription);
	//NILARG_EXCEPTION_TEST(aContext);

	self = [self commonInitWithUUID: aUUID 
	              entityDescription: anEntityDescription
	                        context: aContext
	                        isFault: isFault];

	/* When the object is not reloaded, but instantiated for the first time */
	if (isFault == NO)
	{
		[self init];
	}
	return self;
}

- (id) init
{
	if (_isInitialized == NO)
	{
		SUPERINIT;
		self = [self commonInitWithUUID: [ETUUID UUID]
		              entityDescription: nil
		                        context: nil
		                        isFault: NO];
	}
	return self;
}

- (void)dealloc
{
	_persistentRoot = nil;
	DESTROY(_uuid);
	DESTROY(_entityDescription);
	DESTROY(_variableStorage);
	[super dealloc];
}

- (void)becomePersistentInContext: (COPersistentRoot *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
	INVALIDARG_EXCEPTION_TEST(aContext, [aContext conformsToProtocol: @protocol(COPersistentObjectContext)]);
	if ([aContext isKindOfClass: [COPersistentRoot class]])
	{
		//INVALIDARG_EXCEPTION_TEST(aContext, [(COPersistentRoot *)aContext rootObject] != self);
	}
	if (_persistentRoot != nil)
	{
		[NSException raise: NSInternalInconsistencyException
					format: _(@"You must not sent -becomePersistentInContext:, "
		                       "to %@, the object is already persistent in %@"),
		                     [self primitiveDescription], _persistentRoot];
	}
	
	/* Both transient and persistent objects must have a valid UUID */
	ETAssert(_uuid != nil);
	_persistentRoot = aContext;
	if (_entityDescription == nil)
	{
		ASSIGN(_entityDescription, [[(id)aContext modelRepository] entityDescriptionForClass: [self class]]);
	}
	[aContext registerObject: self];
}

- (id) copyWithZone: (NSZone *)aZone usesModelDescription: (BOOL)usesModelDescription
{
	COObject *newObject = [[self class] allocWithZone: aZone];
	
	newObject->_uuid = [[ETUUID alloc] init];
	newObject->_persistentRoot = _persistentRoot;
	if (_variableStorage != nil)
	{
		newObject->_variableStorage = [self newVariableStorage];

		if (usesModelDescription)
		{
			// TODO: For variable storage properties, support a metamodel-driven copy
			// Share support code with -insertObjectCopy: or make -insertObjectCopy: 
			// uses -copyWithZone:
		}
	}

	return newObject;
}

- (id) copyWithZone: (NSZone *)aZone
{
	return [self copyWithZone: aZone usesModelDescription: NO];
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

- (COPersistentRoot *)persistentRoot
{
	return _persistentRoot;
}

- (COObject *) rootObject
{
	return [_persistentRoot rootObject];
}

- (BOOL) isRoot
{
	return ([self rootObject] == self);
}

- (BOOL) isFault
{
	return NO;
}

- (CORevision *)revision
{
	return [_persistentRoot revision];
}

- (BOOL) isPersistent
{
	return (_persistentRoot != nil);
	// TODO: Switch to the code below on root object are saved in the db
	// return (_persistentRoot != nil && _rootObject != nil);
}

- (BOOL) isDamaged
{
	return [[self persistentRoot] isUpdatedObject: self];
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

- (NSSet *)allInnerObjects
{
	if ([self isRoot] == NO)
		return nil;

	if ([self isPersistent] == NO)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Inner objects cannot be known until %@ has become persistent", self];
	}

	CORevision *loadedRev = [_persistentRoot revision];

	ETUUID *trackUUID = [[[self persistentRoot] commitTrack] UUID];
	NSSet *innerObjectUUIDs = [[[self persistentRoot] store] objectUUIDsForCommitTrackUUID: trackUUID
	                                                                            atRevision: loadedRev];
	NSMutableSet *innerObjects = [NSMutableSet setWithCapacity: [innerObjectUUIDs count]];

	for (ETUUID *uuid in innerObjectUUIDs)
	{
		[innerObjects addObject: [[_persistentRoot parentContext] objectWithUUID: uuid]];
	}
	return innerObjects;
}

- (NSSet *)allInnerObjectsIncludingSelf
{
	return [[self allInnerObjects] setByAddingObject: self];
}

- (NSString *)displayName
{
	return [self name];
}

- (NSString *)name
{
	return [self valueForUndefinedKey: @"name"];
}

- (NSString *)identifier
{
	return [self name];
}

- (void)setName: (NSString *)aName
{
	[self willChangeValueForProperty: @"name"];
	[self setValue: aName forUndefinedKey: @"name"];
	[self didChangeValueForProperty: @"name"];
}

- (NSDate *)modificationDate
{
	CORevision *rev = [[[self persistentRoot] store] maxRevision: INT64_MAX 
	                                           forRootObjectUUID: [[self rootObject] UUID]];
	return [rev date];
}

- (NSDate *)creationDate
{
	CORevision *rev = [[[self persistentRoot] store] maxRevision: 0 
	                                           forRootObjectUUID: [[self rootObject] UUID]];
	return [rev date];
}

- (NSArray *)parentGroups
{
	return [self valueForProperty: @"parentCollections"];
}

- (NSArray *)tags
{
	return [self primitiveValueForKey: @"tags"];
}

/* Property-value coding */

- (NSSet *) observableKeyPaths
{
	return S(@"name", @"lastVersionDescription", @"tagDescription");
}

- (NSArray *)propertyNames
{
	return [[self entityDescription] allPropertyDescriptionNames];
}

- (NSArray *) persistentPropertyNames
{
	return (id)[[[[self entityDescription] allPersistentPropertyDescriptions] mappedCollection] name];
}

- (id) valueForProperty:(NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to get value for invalid property %@", key];
		return nil;
	}
	
	return [super valueForKey: key];
}

+ (BOOL) isPrimitiveCoreObjectValue: (id)value
{  
	return [value isKindOfClass: [NSNumber class]] ||
		[value isKindOfClass: [NSDate class]] ||
		[value isKindOfClass: [NSData class]] ||
		[value isKindOfClass: [NSString class]] ||
		[value isKindOfClass: [COObject class]] ||
		[value isKindOfClass: [COObjectFault class]] ||
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

/* Makes sure the value is in the same context as us. */
- (void)checkEditingContextForValue:(id)value
{
	if ([value isKindOfClass: [NSArray class]] ||
		[value isKindOfClass: [NSSet class]])
	{
		for (id subvalue in value)
		{
			[self checkEditingContextForValue: subvalue];
		}
	}
	else 
	{
		if ([value isKindOfClass: [COObject class]])
		{
			assert([[value persistentRoot] parentContext] == [_persistentRoot parentContext]);
		}    
	}
}

- (void)updateRelationshipConsistencyForProperty: (NSString *)key oldValue: (id)oldValue
{
	// FIXME: use the metamodel's validation support?
	if (_isIgnoringRelationshipConsistency)
		return;

	[self setIgnoringRelationshipConsistency: YES]; // Needed to guard against recursion
	
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	assert(desc != nil);
	
	if ([desc opposite] != nil)
	{
		NSString *oppositeName = [[desc opposite] name];
		if (![desc isMultivalued]) // modifying the single-valued side of a relationship
		{
			COObject *oldContainer = oldValue;
			COObject *newContainer = [self valueForProperty: key];
			
			if (newContainer != oldContainer)
			{					
				[oldContainer setIgnoringRelationshipConsistency: YES];
				[newContainer setIgnoringRelationshipConsistency: YES];			
				
				if ([[desc opposite] isMultivalued])
				{
					[oldContainer removeObject: self atIndex: ETUndeterminedIndex hint: nil forProperty: oppositeName];
					[newContainer insertObject: self atIndex: ETUndeterminedIndex hint: nil forProperty: oppositeName];			
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
			id newValue = [self valueForProperty: key];
			NSMutableSet *newObjects;
	
			if ([newValue isKindOfClass: [NSSet class]])
			{
				newObjects = [NSMutableSet setWithSet: newValue];
			}			
			else if (newValue == nil)
			{
				newObjects = [NSMutableSet set]; // Should usually never happen
			}
			else
			{
				newObjects = [NSMutableSet setWithArray: newValue];
			}
			
			NSMutableSet *oldObjects;
			if ([oldValue isKindOfClass: [NSSet class]])
			{
				oldObjects = [NSMutableSet setWithSet: oldValue];
			}
			else if (oldValue == nil)
			{
				oldObjects = [NSMutableSet set]; // Should only happen when an object is first created
			}
			else
			{
				oldObjects = [NSMutableSet setWithArray: oldValue];
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
					[oldObj removeObject: self atIndex: ETUndeterminedIndex hint: nil forProperty: oppositeName];
				}
				for (COObject *newObj in newObjects)
				{
					[newObj insertObject: self atIndex: ETUndeterminedIndex hint: nil forProperty: oppositeName];
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
					id oldContainer = [newObj valueForProperty: oppositeName];

					[oldContainer setIgnoringRelationshipConsistency: YES];
					
					[oldContainer removeObject: newObj atIndex: ETUndeterminedIndex hint: nil forProperty: key];
					[newObj setValue: self forProperty: oppositeName];
				
					[oldContainer setIgnoringRelationshipConsistency: NO];
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

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	/* We call the setter directly if implemented */

	NSString *setterName = [@"set" stringByAppendingString: [key capitalizedString]];
	SEL setter = NSSelectorFromString(setterName);

	if ([self respondsToSelector: setter])
	{
		// NOTE: We could -setValue:forKey: to get a fallback on 
		// -setValue:forUndefinedKey: if we have a type mistmatch between the 
		// value and the setter argument.
		[self performSelector: setter withObject: value];
		return YES;
	}

	/* Otherwise we do the integrity check, update the variable storage, and 
	   trigger the change notifications */

	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
		return NO;
	}

	// FIXME: Move this check elsewhere or rework it because it can break on 
	// transient values or archived objects such as NSColor, NSView.
	//if (![COObject isCoreObjectValue: value])
	//{
	//	[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	//}

 	BOOL isMultivalued = [[[self entityDescription] propertyDescriptionForName: key] isMultivalued];
	id oldValue = [self valueForProperty: key];
	 
	 oldValue = (isMultivalued ? [oldValue mutableCopy] : [oldValue retain]);

	[self checkEditingContextForValue: value];

	[self willChangeValueForProperty: key];
	[self setPrimitiveValue: value forKey: key];
	[self didChangeValueForProperty: key oldValue: oldValue];

	return YES;
}

- (NSArray *)validateAllValues
{
	NSMutableArray *results = [NSMutableArray array];

	// TODO: We might want to coalesce bidirectional relationships validation results
	for (NSString *key in [self persistentPropertyNames])
	{
		[results addObjectsFromArray: [self validateValue: [self valueForProperty: key] 
		                                      forProperty: key]];
	}
	return results;
}

- (ETValidationResult *)validateValueUsingMetamodel: (id)value forProperty: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
	ETPropertyDescription *opposite = [propertyDesc opposite];
	ETValidationResult *oppositeResult = nil;

	if (opposite != nil)
	{
		NSString *oppositeKey = [opposite name];
		id oppositeValue = [value valueForProperty: oppositeKey];

		oppositeResult = [opposite validateValue: oppositeValue forKey: oppositeKey];
	}
	
	ETValidationResult *result = [propertyDesc validateValue: value forKey: key];
	// TODO: [result setOppositeResult: oppositeResult];

	return result;
}

- (ETValidationResult *)validateValueUsingPVC: (id)value forProperty: (NSString *)key
{
	SEL keySelector = NSSelectorFromString([NSString stringWithFormat: @"validate%@:", [key capitalizedString]]);

	if ([self respondsToSelector: keySelector] == NO)
		return [ETValidationResult validResult: value];

	return [self performSelector: keySelector withObject: value];
}

// TODO: If we want to support -validateValue:forKey:error: too, implement 
// -validateUsingKVC:forProperty:
// TODO: Would be cleaner to return an aggregate validation result
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key
{
	ETValidationResult *result = [self validateValueUsingMetamodel: value forProperty: key];
	ETValidationResult *pvcResult = [self validateValueUsingPVC: value forProperty: key];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity: 2];

	if ([result isValid] == NO)
	{
		[results addObject: result];
	}
	if ([pvcResult isValid] == NO)
	{
		[results addObject: pvcResult];
	}
	return results;
}

- (NSError *)validateForInsert
{
	return nil;
}

- (NSError *)validateForUpdate
{
	return [COError errorWithValidationResults: [self validateAllValues]];
}

- (NSError *)validateForDelete
{
	return nil;
}

- (BOOL)validateValue:(id *)aValue forKey:(NSString *)key error:(NSError **)anError
{
	NSArray *results = [self validateValue: *aValue forProperty: key];

	if ([results count] == 1 && [[results firstObject] isValid])
		return YES;

	*aValue = [[results lastObject] value];
	*anError = [COError errorWithValidationResults: results];
	return NO;
}

- (id)primitiveValueForKey: (NSString *)key
{
	id value = [_variableStorage objectForKey: key];
	return (value == [NSNull null] ? nil : value);
}

- (void)setPrimitiveValue: (id)value forKey: (NSString *)key
{
	[_variableStorage setObject: (value == nil ? [NSNull null] : value)
						 forKey: key];
}

- (id)valueForUndefinedKey: (NSString *)key
{
	return [self primitiveValueForKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
	[self setPrimitiveValue: value forKey: key];
}

- (void)willChangeValueForProperty: (NSString *)key
{
	[super willChangeValueForKey: key];
}

- (void) notifyContextOfDamageIfNeededForProperty: (NSString*)prop
{
	if (!_isIgnoringDamageNotifications)
	{
		[[self persistentRoot] markObjectUpdated: self forProperty: prop];
	}
}

- (void)didChangeValueForProperty: (NSString *)key
{
	[self didChangeValueForProperty: key oldValue: nil];
}

- (void)didChangeValueForProperty: (NSString *)key oldValue: (id)oldValue
{
	// TODO: Evaluate whether -checkEditingContextForValue: is too costly
	//[self checkEditingContextForValue: [self valueForProperty: key]];
	[self updateRelationshipConsistencyForProperty: key oldValue: oldValue];
	[self notifyContextOfDamageIfNeededForProperty: key];
	[super didChangeValueForKey: key];
}


- (id)collectionForProperty: (NSString *)key insertionIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForProperty: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException 
						format: @"Attempt to call addObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]] || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException 
						format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call insertObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForProperty: key] mutableCopy];
	id collection = [self collectionForProperty: key insertionIndex: index];

	[self willChangeValueForProperty: key];
	[collection insertObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

- (id)collectionForProperty: (NSString *)key removalIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForProperty: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call removeObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]] || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call removeObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForProperty: key] mutableCopy];
	id collection = [self collectionForProperty: key removalIndex: index];

	[self willChangeValueForProperty: key];
	[collection removeObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

- (void)awakeFromFetch
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

- (void)willTurnIntoFault
{

}

- (void)didTurnIntoFault
{

}

- (void)didReload
{

}

- (NSUInteger)hash
{
	return [_uuid hash] ^ 0x39ab6f39b15233de;
}

- (BOOL)isEqual: (id)anObject
{
	if (anObject == self)
	{
		return YES;
	}
	if (![anObject isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[anObject UUID] isEqual: _uuid])
	{
		return YES;
	}
	return NO;
}

- (BOOL)isDeeplyEqual: (id)object
{
	// FIXME: Incomplete/incorrect
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
	return NO;
}

- (BOOL) isTemporalInstance: (id)anObject
{
	if (anObject == self)
	{
		return YES;
	}
	if (![anObject isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[anObject UUID] isEqual: _uuid] && [[anObject revision] isEqual: [self revision]])
	{
		return YES;
	}
	return NO;
}

- (COCommitTrack *)commitTrack
{
	return [[self persistentRoot] commitTrack];
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	// TODO: Check and traverse relationships to visit the object graph
	return ([[aQuery predicate] evaluateWithObject: self] ? A(self) : [NSArray array]);
}

- (id)roundTripValueForProperty: (NSString *)key
{
	id plist = [self propertyListForValue: [self serializedValueForProperty: key]];
	return [self valueForPropertyList: plist];
}

static int indent = 0;

- (NSString *)detailedDescription
{
	if (_inDescription)
	{
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	}
	_inDescription = YES;
	indent++;
	NSMutableString *str = [NSMutableString stringWithFormat: @"<%@(%@) at %p UUID %@ data: {\n",  [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	indent++;
	
	NSMutableArray *props = [NSMutableArray arrayWithArray: [self persistentPropertyNames]];
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

- (NSString *)description
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

- (NSString *)typeDescription
{
	return [[self entityDescription] localizedDescription];
}

- (NSString *)tagDescription
{
	return [(NSArray *)[[[self tags] mappedCollection] tagString] componentsJoinedByString: @", "];
}

/* 
 * Private 
 */

+ (Class)faultClass
{
	return [COObjectFault class];
}

- (void)turnIntoFault
{
	if ([self isFault])
		return;

	[self willTurnIntoFault];
	ASSIGN(_variableStorage, nil);
	object_setClass(self, [[self class] faultClass]);
	[self didTurnIntoFault];
}

- (NSError *)unfaultIfNeeded
{
	ETAssert([self isFault] == NO);
	return nil;
}

- (BOOL)isIgnoringRelationshipConsistency
{
	return _isIgnoringRelationshipConsistency;
}

- (void)setIgnoringRelationshipConsistency: (BOOL)ignore
{
	_isIgnoringRelationshipConsistency = ignore;
}

- (id)serializedValueForProperty: (NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to get value for invalid property %@", key];
	}

	/* First we try to use the getter named 'serialized' + 'key' */

	// TODO: Probably a bit slow, rewrite in C a bit
	NSString *capitalizedKey = [key stringByReplacingCharactersInRange: NSMakeRange(0, 1) 
	                                                        withString: [[key substringToIndex: 1] uppercaseString]];
	SEL getter = NSSelectorFromString([@"serialized" stringByAppendingString: capitalizedKey]);

	if ([self respondsToSelector: getter])
	{
		return [self performSelector: getter];
	}	

	/* If no custom getter can be found, we use PVC which will in last resort 
	   access the variable storage with -primitiveValueForKey: */

	return [self valueForProperty: key];
}

- (void)setSerializedValue: (id)value forProperty: (NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
	}
	if ([value isCollection] && [value isMutableCollection] == NO)
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set immutable collection %@", key];
	}
	// TODO: We should check (but not update) the relationship consistency in a 
	// vein similar to [self updateRelationshipConsistencyWithValue: value forProperty: key];

	[self checkEditingContextForValue: value];
	
	/* First we try to use the setter named 'setSerialized' + 'key' */

	// TODO: Probably a bit slow, rewrite in C a bit
	NSString *capitalizedKey = [key stringByReplacingCharactersInRange: NSMakeRange(0, 1) 
	                                                        withString: [[key substringToIndex: 1] uppercaseString]];
	SEL setter = NSSelectorFromString([NSString stringWithFormat: @"%@%@%@", 
		@"setSerialized", capitalizedKey, @":"]);

	if ([self respondsToSelector: setter])
	{
		[self performSelector: setter withObject: value];
		return;
	}	
	
	/* When no custom setter can be found, we try to access the ivar with KVC semantics */

	[self willChangeValueForProperty: key];

	if (ETSetInstanceVariableValueForKey(self, value, key) == NO)
	{
		/* If no valid ivar can be found, we access the variable storage */
		[self setPrimitiveValue: value forKey: key];
	}

	[self didChangeValueForProperty: key];
}

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

/* Returns the CoreObject serialized type for a NSValue or NSNumber object.

Nil is returned when the type is unsupported by CoreObject serialization. */
- (NSString *)typeForValue: (id)value
{
	const char *type = [value objCType];

	if  (strcmp(type, @encode(NSPoint)) == 0)
	{
		return @"point";
	}
	else if (strcmp(type, @encode(NSSize)) == 0)
	{
		return @"size";
	}
	else if (strcmp(type, @encode(NSRect)) == 0)
	{
		return @"rect";
	}
	else if (strcmp(type, @encode(NSRange)) == 0)
	{
		return @"range";
	}
	else if (strcmp(type, @encode(SEL)) == 0)
	{
		return @"sel";
	}
	return nil;
}

/* See ETGeometry.h in EtoileUI */
static const NSPoint CONullPoint = {FLT_MIN, FLT_MIN};
static const NSSize CONullSize = {FLT_MIN, FLT_MIN};
static const NSRect CONullRect = {{FLT_MIN, FLT_MIN}, {FLT_MIN, FLT_MIN}};

/* Returns the CoreObject serialization result for a NSValue or NSNumber object.

Nil is returned when the value type is unsupported by CoreObject serialization. */
- (NSString *)stringValueForValue: (id)value
{
	const char *type = [value objCType];

	if  (strcmp(type, @encode(NSPoint)) == 0)
	{
		NSPoint point = [value pointValue];
		if (NSEqualPoints(point, CONullPoint))
		{
			return @"null-point";
		}
		return NSStringFromPoint(point);
	}
	else if (strcmp(type, @encode(NSSize)) == 0)
	{
		NSSize size = [value sizeValue];
		if (NSEqualSizes(size, CONullSize))
		{
			return @"null-size";
		}
		return NSStringFromSize(size);
	}
	else if (strcmp(type, @encode(NSRect)) == 0)
	{
		NSRect rect = [value rectValue];
		if (NSEqualRects(rect, CONullRect))
		{
			return @"null-rect";
		}
		return NSStringFromRect(rect);
	}
	else if (strcmp(type, @encode(NSRange)) == 0)
	{
		return NSStringFromRange([value rangeValue]);
	}
	else if (strcmp(type, @encode(SEL)) == 0)
	{
		return NSStringFromSelector((SEL)[value pointerValue]);
	}
	return nil;
}

- (NSDictionary *)propertyListForValue: (id)value
{
	NSDictionary *result = nil;

	/* Some root object relationships are special in the sense the value can be 
	   a core object but its persistency isn't enabled. We interpret these 
	   one-to-one relationships as transient.
	   Usually a root object belongs to some other objects at run-time, in some 
	   cases the root object  want to hold a backward pointer (inverse 
	   relationship) to those non-persistent object(s).
	   For example, a root object can be a layout item whose parent item is the 
	   window group... In such a case, we don't want to persist the window 
	   group, but ignore it. At deseserialiation time, the app is responsible 
	   to add the item back to the window group (the parent item would be 
	   restored then). */
	if ([value isKindOfClass: [COObject class]])
	{
		if ([value isPersistent])
		{
			result = [value referencePropertyList];
		}
		else
		{
			ETAssert([self isRoot]);
			result = D(@"nil", @"type");
		}
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
	else if ([value isKindOfClass: [NSValue class]] && [self typeForValue: value] != nil)
	{
		result = D([self stringValueForValue: value], @"value", [self typeForValue: value] , @"type");
	}
	else
	{
		// FIXME: Perhaps add a method which can be overriden to explicitly 
		// declare which instances we can encode without raising an exception.
		// For example... -validCoreObjectDataClasses.
		// Would be better to get these from [ETPropertyDescription type].
		result = (NSDictionary *)[NSKeyedArchiver archivedDataWithRootObject: value];
	
		//[NSException raise: NSInvalidArgumentException
		//            format: @"value must of type COObject, NSArray, NSSet or nil"];
		//return nil;
	}
	return result;
}

- (NSDictionary *)referencePropertyList
{
	NSAssert1([self isPersistent], 
		@"Usually means -becomePersistentInContext: hasn't been called on %@", self);

	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"object-ref", @"type",
			[_uuid stringValue], @"uuid",
			[_entityDescription fullName], @"entity",
			nil];
}

- (NSObject *)valueForPropertyList: (NSObject *)plist
{
	// TODO: Could move the string to NSValue handling to a new method 
	// -valueForString:... Would be more symetric if we allow subclasses to 
	// declare new value types

	if ([plist isKindOfClass: [NSDictionary class]])
	{
		NSString *type = [plist valueForKey: @"type"];

		if ([type isEqualToString: @"object-ref"])
		{
			ETUUID *uuid = [ETUUID UUIDWithString: [plist valueForKey: @"uuid"]];
			return [[[self persistentRoot] parentContext] objectWithUUID: uuid
			                                                  entityName: [plist valueForKey: @"entity"]
			                                                  atRevision: nil];
		}
		else if ([type isEqualToString: @"unorderedCollection"])
		{
			NSArray *objects = [plist valueForKey: @"objects"];
			NSMutableSet *set = [NSMutableSet setWithCapacity: [objects count]];
			for (int i = 0; i < [objects count]; i++)
			{
				[set addObject: [self valueForPropertyList: [objects objectAtIndex:i]]];
			}
			return set;
		}
		else if ([type isEqualToString: @"nil"])
		{
			return nil;
		}
		else if ([type isEqualToString: @"primitive"])
		{
			return [plist valueForKey: @"value"];
		}
		else if ([type isEqualToString: @"point"])
		{
			NSString *pointString = [plist valueForKey: @"value"];
			NSPoint point;
			if ([pointString isEqualToString: @"null-point"])
			{
				point = CONullPoint;
			}
			else
			{
				point = NSPointFromString(pointString);
			}
			return [NSValue valueWithPoint: point];
		}
		else if ([type isEqualToString: @"size"])
		{
			NSString *sizeString = [plist valueForKey: @"value"];
			NSSize size;
			if ([sizeString isEqualToString: @"null-size"])
			{
				size = CONullSize;
			}
			else
			{
				size = NSSizeFromString(sizeString);
			}
			return [NSValue valueWithSize: size];
		}
		else if ([type isEqualToString: @"rect"])
		{
			NSString *rectString = [plist valueForKey: @"value"];
			NSRect rect;
			if ([rectString isEqualToString: @"null-rect"])
			{
				rect = CONullRect;
			}
			else
			{
				rect = NSRectFromString(rectString);
			}
			return [NSValue valueWithRect: rect];
		}
		else if ([type isEqualToString: @"range"])
		{
			return [NSValue valueWithRange: NSRangeFromString([plist valueForKey: @"value"])];
		}
		else if ([type isEqualToString: @"sel"])
		{
			SEL sel = NSSelectorFromString([plist valueForKey: @"value"]);
			return [NSValue valueWithBytes: &sel objCType: @encode(SEL)];
		}
	}
	else if ([plist isKindOfClass: [NSArray class]])
	{
		NSUInteger count = [(NSArray*)plist count];
		id mapped[count];
		for (int i = 0; i < count; i++)
		{
			id obj = [self valueForPropertyList: [(NSArray*)plist objectAtIndex:i]];
			mapped[i] = obj;
		}
		return [NSMutableArray arrayWithObjects: mapped count: count];
	}
	else if ([plist isKindOfClass: [NSData class]])
	{
		return [NSKeyedUnarchiver unarchiveObjectWithData: (NSData *)plist];
	}

	return plist;
}

@end
