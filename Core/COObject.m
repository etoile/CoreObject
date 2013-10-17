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
#import "CODictionary.h"
#import "COError.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COObject+RelationshipCache.h"
#import "CORelationshipCache.h"
#import "COSQLiteStore.h"
#import "COTag.h"
#import "COGroup.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COSerialization.h"
#import "COEditingContext+Private.h"
#import "CORevision.h"
#include <objc/runtime.h>

@implementation COObject

@synthesize UUID = _UUID, entityDescription = _entityDescription,
	objectGraphContext = _objectGraphContext;

// For EtoileUI
/** <override-dummy />
Returns <em>CO</em>.
 
See +[NSObject typePrefix]. */
+ (NSString *) typePrefix
{
	return @"CO";
}

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

	/* Persistency Attributes (subset) */

	ETPropertyDescription *UUID =
		[ETPropertyDescription descriptionWithName: @"UUID" type: (id)@"ETUUID"];
	ETPropertyDescription *isPersistent =
		[ETPropertyDescription descriptionWithName: @"isPersistent" type: (id)@"BOOL"];
	ETPropertyDescription *isRoot =
		[ETPropertyDescription descriptionWithName: @"isRoot" type: (id)@"BOOL"];

	/* Basic Properties */

	ETPropertyDescription *name =
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"NSString"];
	ETPropertyDescription *identifier =
		[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"NSString"];
	ETPropertyDescription *tags  =
		[ETPropertyDescription descriptionWithName: @"tags" type: (id)@"COTag"];
	[tags setMultivalued: YES];
	[tags setOrdered: YES];

	// TODO: Move these properties to EtoileFoundation (by adding a NSObject
	// entity description) or just use -basicPropertyNames in
	//-[COObject propertyNames]... See -[NSObject propertyNames] and remove
	// some properties in -basicPropertyNames (e.g. hash or superclass).

#ifndef GNUSTEP 
	// FIXME: We don't link NSImage on GNUstep because AppKit won't work
	ETPropertyDescription *icon = 
		[ETPropertyDescription descriptionWithName: @"icon" type: (id)@"NSImage"];
#endif
	ETPropertyDescription *displayName = 
		[ETPropertyDescription descriptionWithName: @"displayName" type: (id)@"NSString"];

	/* Description Properties */

	ETPropertyDescription *revisionDescription =
		[ETPropertyDescription descriptionWithName: @"revisionDescription" type: (id)@"NSString"];
	ETPropertyDescription *tagDescription =
		[ETPropertyDescription descriptionWithName: @"tagDescription" type: (id)@"NSString"];
	ETPropertyDescription *typeDescription =
		[ETPropertyDescription descriptionWithName: @"typeDescription" type: (id)@"NSString"];

	NSArray *transientProperties = A(UUID, isPersistent, isRoot, identifier,
		displayName, revisionDescription, tagDescription, typeDescription);
#ifndef GNUSTEP
	transientProperties = [transientProperties arrayByAddingObject: icon];
#endif
	NSArray *persistentProperties = A(name, tags);
	NSArray *properties =
		[transientProperties arrayByAddingObjectsFromArray: persistentProperties];

	[[[properties arrayByRemovingObject: @"name"] mappedCollection] setReadOnly: YES];
	[[persistentProperties mappedCollection] setPersistent: YES];

	[object setPropertyDescriptions: properties];

	return object;
}

#pragma mark - Initialization

- (Class)collectionClassForPropertyDescription: (ETPropertyDescription *)propDesc
{
	NSParameterAssert([propDesc isMultivalued]);

	if ([propDesc isKeyed])
	{
		return ([propDesc isPersistent] ? [CODictionary class] : [NSDictionary class]);
	}
	else
	{
		return ([propDesc isOrdered] ? [NSArray class] : [NSSet class]);
	}
}

- (id)newCollectionForPropertyDescription: (ETPropertyDescription *)propDesc
{
	Class class = [self collectionClassForPropertyDescription: propDesc];
	ETAssert([class conformsToProtocol: @protocol(ETCollection)]);

	if ([class isSubclassOfClass: [CODictionary class]])
	{
		return [[CODictionary alloc] initWithObjectGraphContext: _objectGraphContext];
	}
	return [[class mutableClass] new];
}

- (NSMutableDictionary *)newVariableStorage
{
	NSMutableDictionary *variableStorage = [[NSMutableDictionary alloc] initWithCapacity: 20];

	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued] == NO || [propDesc isDerived])
			continue;

		id value = nil;
		BOOL ivarExists = ETGetInstanceVariableValueForKey(self, &value, [propDesc name]);

		if (ivarExists)
			continue;

		id collection = [self newCollectionForPropertyDescription: propDesc];
		
		[variableStorage setObject: collection forKey: [propDesc name]];
	}

	return variableStorage;
}

- (NSMutableDictionary *)newOutgoingRelationshipCache
{
	NSMutableDictionary *variableStorage = [[NSMutableDictionary alloc] initWithCapacity: 5];

	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued] == NO || [propDesc isKeyed] || [propDesc isPersistent] == NO)
			continue;

		ETAssert([propDesc isDerived] == NO);

		id collection = [self newCollectionForPropertyDescription: propDesc];

		[variableStorage setObject: collection forKey: [propDesc name]];
	}

	return variableStorage;
}

- (void)validateEntityDescription: (ETEntityDescription *)anEntityDescription
     inModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	Class entityClass = [repo classForEntityDescription: anEntityDescription];

	if ([entityClass isSubclassOfClass: [self class]] == NO
	 && [[self class] isSubclassOfClass: entityClass] == NO)
	{
		[NSException raise: NSInvalidArgumentException
					format: @"There is mismatch between the entity description "
		                     "%@ and the class %@. For this entity description, "
		                     "the class must be a %@ class, subclass or superclass.",
		                     [anEntityDescription fullName], [self className],
		                     NSStringFromClass(entityClass)];
	}
}

- (id) commonInitWithUUID: (ETUUID *)aUUID 
        entityDescription: (ETEntityDescription *)anEntityDescription
       objectGraphContext: (COObjectGraphContext *)aContext
					isNew: (BOOL)inserted
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anEntityDescription);
	NILARG_EXCEPTION_TEST(aContext);
	INVALIDARG_EXCEPTION_TEST(aContext, [aContext isKindOfClass: [COObjectGraphContext class]]);

	[self validateEntityDescription: anEntityDescription
	   inModelDescriptionRepository: [aContext modelRepository]];

	_UUID = aUUID;
	_entityDescription =  anEntityDescription;
	_objectGraphContext = aContext;
	_isInitialized = YES;
	_variableStorage = [self newVariableStorage];
    _outgoingSerializedRelationshipCache = [self newOutgoingRelationshipCache];
	_incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];

	[_objectGraphContext registerObject: self isNew: inserted];

	return self;
}

- (id)initWithUUID: (ETUUID *)aUUID 
 entityDescription: (ETEntityDescription *)anEntityDescription
objectGraphContext: (COObjectGraphContext *)aContext
{
	SUPERINIT;
	self = [self commonInitWithUUID: aUUID 
	              entityDescription: anEntityDescription
	             objectGraphContext: aContext
	                          isNew: YES];
	if (!(self = [self init])) return nil;
	return self;
}

- (id)initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	if (_isInitialized)
		return self;

	NILARG_EXCEPTION_TEST(aContext);

	SUPERINIT;
	ETModelDescriptionRepository *repo = [aContext modelRepository];
	return [self commonInitWithUUID: [ETUUID UUID]
	              entityDescription: [repo entityDescriptionForClass: [self class]]
	             objectGraphContext: aContext
	                          isNew: YES];
}

- (id)init
{
	return [self initWithObjectGraphContext: nil];
}

- (id) initWithEntityDescription: (ETEntityDescription *)anEntityDesc
              objectGraphContext: (COObjectGraphContext *)aContext
{
	return [self initWithUUID: [ETUUID UUID]
	        entityDescription: anEntityDesc
	       objectGraphContext: aContext];
}

- (BOOL)isSharedInstance
{
	return [[[[self class] ifResponds] sharedInstance] isEqual: self];
}

// TODO: Maybe add convenience copying method, - (COObject *) copyWithCopier: (COCopier *)aCopier
// where the copier stores the state relating to copying, e.g. which context to copy into.

// TODO: Migrate EtoileUI to COCopier and remove. COObject should not respond to
// -copyWithZone:
- (id) copyWithZone: (NSZone *)aZone
{
	COObject *newObject = [[self class] allocWithZone: aZone];
	
	newObject->_UUID = [[ETUUID alloc] init];
	newObject->_objectGraphContext = _objectGraphContext;
	if (_variableStorage != nil)
	{
		newObject->_variableStorage = [self newVariableStorage];
        newObject->_outgoingSerializedRelationshipCache = [self newOutgoingRelationshipCache];
        newObject->_incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
	}

	return newObject;
}

#pragma mark - Persistency Attributes

- (COPersistentRoot *)persistentRoot
{
	return [_objectGraphContext persistentRoot];
}

- (id) rootObject
{
	return [_objectGraphContext rootObject];
}

- (BOOL) isRoot
{
	return ([self rootObject] == self);
}

- (CORevision *)revision
{
	return [[_objectGraphContext branch] currentRevision];
}

- (BOOL) isPersistent
{
	return ([self persistentRoot] != nil);
}

#pragma mark - Basic Properties

- (NSString *)displayName
{
	return [self name];
}

- (NSString *)name
{
	return [self valueForVariableStorageKey: @"name"];
}

- (NSString *)identifier
{
	return [self name];
}

- (void)setName: (NSString *)aName
{
	[self willChangeValueForProperty: @"name"];
	[self setValue: aName forVariableStorageKey: @"name"];
	[self didChangeValueForProperty: @"name"];
}

- (NSArray *)tags
{
	return [self valueForVariableStorageKey: @"tags"];
}

#pragma mark - Property-Value Coding

- (NSSet *) observableKeyPaths
{
	return S(@"isPersistent", @"name", @"displayName", @"tags",
		@"revisionDescription", @"tagDescription");
}

- (NSArray *)propertyNames
{
	return [[self entityDescription] allPropertyDescriptionNames];
}

- (NSArray *) persistentPropertyNames
{
	return (id)[[[[self entityDescription] allPersistentPropertyDescriptions] mappedCollection] name];
}

- (SEL)getterForKey: (NSString *)key useIsPrefix: (BOOL)useIsPrefix
{
	NSString *getterName = nil;

	if (useIsPrefix)
	{
		getterName = [NSString stringWithFormat: @"is%@", [key stringByCapitalizingFirstLetter]];
	}
	else
	{
		getterName = [NSString stringWithFormat: @"%@", key];
	}
	return NSSelectorFromString(getterName);
}

- (SEL)setterForKey: (NSString *)key
{
	NSString *setterName =
		[NSString stringWithFormat: @"set%@:", [key stringByCapitalizingFirstLetter]];
	return NSSelectorFromString(setterName);
}

- (id) valueForProperty: (NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Tried to get value for invalid property %@", key];
		return nil;
	}
	
	/* We call the getter directly if implemented */

	if ([self respondsToSelector: [self getterForKey: key useIsPrefix: NO]]
	 || [self respondsToSelector: [self getterForKey: key useIsPrefix: YES]])
	{
		// NOTE: Don't use -performSelector:withObject: because it doesn't
		// support unboxing scalar values as Key-Value Coding does.
		return [self valueForKey: key];
	}

	/* Otherwise access ivar or variable storage */

	return [self valueForStorageKey: key];
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
			ETAssert([[value persistentRoot] parentContext] == [[self persistentRoot] parentContext]);
		}    
	}
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Tried to set value for invalid property %@", key];
		return NO;
	}

	/* We call the setter directly if implemented */

	if ([self respondsToSelector: [self setterForKey: key]])
	{
		// NOTE: Don't use -performSelector:withObject: because it doesn't
		// support unboxing scalar values as Key-Value Coding does.
		[self setValue: value forKey: key];
		return YES;
	}

	/* Otherwise update ivar or variable storage (relationship caches, object 
	   graph context and observer objects are notified) */

	[self willChangeValueForProperty: key];
    [self setValue: value forStorageKey: key];
	[self didChangeValueForProperty: key];

	return YES;
}

#pragma mark - Validation

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

- (ETValidationResult *)validateValueUsingModel: (id)value forProperty: (NSString *)key
{
	SEL keySelector = NSSelectorFromString([NSString stringWithFormat: @"validate%@:",
		[key stringByCapitalizingFirstLetter]]);

	if ([self respondsToSelector: keySelector] == NO)
		return [ETValidationResult validResult: value];

	return [self performSelector: keySelector withObject: value];
}

// TODO: Would be cleaner to return an aggregate validation result
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key
{
	ETValidationResult *metamodelResult =
		[self validateValueUsingMetamodel: value forProperty: key];
	ETValidationResult *modelResult =
		[self validateValueUsingModel: value forProperty: key];

	NSMutableArray *results = [NSMutableArray arrayWithCapacity: 2];

	if ([metamodelResult isValid] == NO)
	{
		[results addObject: metamodelResult];
	}
	if ([modelResult isValid] == NO)
	{
		[results addObject: modelResult];
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

- (BOOL)validateValue: (id *)aValue forKey: (NSString *)key error: (NSError **)anError
{
	NSParameterAssert(aValue != NULL);
	NSArray *results = [self validateValue: *aValue forProperty: key];

	if ([results count] == 1 && [[results firstObject] isValid])
		return YES;

	*aValue = [[results lastObject] value];
	if (anError != NULL)
	{
		*anError = [COError errorWithValidationResults: results];
	}
	return NO;
}

#pragma mark - Direct Access to Property Storage

- (BOOL)isIncomingRelationship: (ETPropertyDescription *)propDesc
{
	return (![propDesc isPersistent] && nil != [propDesc opposite] && [[propDesc opposite] isPersistent]);
}

/**
 * Can return incoming relationships, although they are not stored in the 
 * variable storage. This allows -valueForStorageKey: and -valueForProperty: to 
 * both return incoming relationships.
 */
- (id)valueForVariableStorageKey: (NSString *)key
{
    ETPropertyDescription *propDesc = [[self entityDescription] propertyDescriptionForName: key];

	// NOTE: In CoreObject, incoming relationships (e.g. parent(s)) are stored 
	// in an incoming relationship cache per object and not persisted, unlike
	// outgoing relationships (e.g. children).
	//
	// For the relationship cache API, parent(s) = referringObject(s) and self = target
    if ([self isIncomingRelationship: propDesc])
    {
        if ([propDesc isMultivalued])
        {
            return [_incomingRelationshipCache referringObjectsForPropertyInTarget: key];
        }
        return [_incomingRelationshipCache referringObjectForPropertyInTarget: key];
    }

	id value = [_variableStorage objectForKey: key];
	return (value == [NSNull null] ? nil : value);
}

- (void)setValue: (id)value forVariableStorageKey: (NSString *)key
{
	[_variableStorage setObject: (value == nil ? [NSNull null] : value)
						 forKey: key];
}

// FIXME: Investigate whether this way of implementing KVC is really KVC compliant
- (id)valueForUndefinedKey: (NSString *)key
{
	return [self valueForVariableStorageKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
	[self setValue: value forVariableStorageKey: key];
}

- (id)valueForStorageKey: (NSString *)key
{
	id value = nil;

	if (ETGetInstanceVariableValueForKey(self, &value, key) == NO)
	{
		value = [self valueForVariableStorageKey: key];
	}
	return value;
}

- (void)setValue: (id)value forStorageKey: (NSString *)key
{
	if (ETSetInstanceVariableValueForKey(self, value, key) == NO)
	{
		[self setValue: value forVariableStorageKey: key];
	}
}

#pragma mark - Notifications to be called by Accessors

- (void)willChangeValueForProperty: (NSString *)key
{
	[super willChangeValueForKey: key];
}

- (void) markAsUpdatedIfNeededForProperty: (NSString*)prop
{	
	[_objectGraphContext markObjectAsUpdated: self forProperty: prop];
}

/**
 * FIXME: This API is broken, see note in -[CORelationshipCache addReferenceFromSourceObject:sourceProperty:targetProperty:]
 * I'm not sure if we can support it. --Eric 
 */
- (void)didChangeValueForProperty: (NSString *)key
{
	[self didChangeValueForProperty: key oldValue: nil];
}

- (void)validateNewValue: (id)newValue
{
	// NOTE: For the CoreObject benchmark, no visible slowdowns but breaks
	// EtoileUI currently.
	//[self checkEditingContextForValue: newValue];
	
  	// FIXME: Move this check elsewhere or rework it because it can break on
	// transient values or archived objects such as NSColor, NSView.
	//if (![COObject isCoreObjectValue: value])
	//{
	//	[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	//}
}

/**
 * For an outgoing relationship, turns COObject elements into ETUUID and COPath 
 * collections that we keep cached.
 *
 * For attributes, and incoming or transient relationships, does nothing.
 *
 * See -updateCrossPersistentRootReferences.
 */
- (void)updateOutgoingSerializedRelationshipCacheForProperty: (NSString *)key
{
	BOOL isOutgoingPersistentRelationship =
		([_outgoingSerializedRelationshipCache objectForKey: key] != nil);

    if (isOutgoingPersistentRelationship == NO)
		return;
	
	// NOTE: We cannot use -serializedValueForPropertyDescription: since the
	// latter method attempts to access the cache we want to update.
	// For relationships, serialization accessors are not allowed, so skipping  
	// -serializedValueForPropertyDescription: doesn't matter.
	id serializedValue = [self serializedValueForValue: [self valueForStorageKey: key]];
	
	//NSLog(@"Outgoing Relationship Cache: setting %@ from %@ to %@", key,
	//     [_outgoingSerializedRelationshipCache objectForKey: key], serializedValue);

	[_outgoingSerializedRelationshipCache setObject: serializedValue forKey: key];
}

- (void)updateCompositeRelationshipForPropertyDescription: (ETPropertyDescription *)propertyDesc
{
	// Remove objects in newValue from their old parents
    // as perscribed by the COEditingContext class docs
    // FIXME: Ugly implementation
    if ([propertyDesc isComposite] == NO)
		return;

	NSString *key = [propertyDesc name];
	ETPropertyDescription *parentDesc = [propertyDesc opposite];
	id aValue = [self valueForStorageKey: key];
	
	for (COObject *objectBeingInserted in ([propertyDesc isMultivalued] ? aValue : [NSArray arrayWithObject: aValue]))
	{
		COObject *objectBeingInsertedParent = [[objectBeingInserted incomingRelationshipCache] referringObjectForPropertyInTarget: [parentDesc name]];
		
		// FIXME: Minor flaw, you can insert a composite twice if the collection is ordered.
		// e.g.
		// (a, b, c) => (a, b, c, a) since we only remove the objects from their old parents if the
		// parent is different than the object we're inserting into
		
		if (objectBeingInsertedParent != nil && objectBeingInsertedParent != self)
		{
			BOOL alreadyRemoved = NO;
			
			if (![[objectBeingInsertedParent valueForStorageKey: key] containsObject: objectBeingInserted])
			{
				// This is sort of a hack for EtoileUI.
				// It handles removing the object from its old parent for us.
				// In that case, don't try to do it ourselves.
				// TODO: Decide the correct way to handle this
				alreadyRemoved = YES;
			}
			
			if (!alreadyRemoved)
			{
				[objectBeingInsertedParent removeObject: objectBeingInserted atIndex: ETUndeterminedIndex hint: nil forProperty: key];
			}
		}
	}
}

- (void)didChangeValueForProperty: (NSString *)key oldValue: (id)oldValue
{
	id newValue = [self valueForStorageKey: key];

	[self validateNewValue: newValue];

	[self updateOutgoingSerializedRelationshipCacheForProperty: key];
	
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    
	[self updateCompositeRelationshipForPropertyDescription: propertyDesc];
    [self updateCachedOutgoingRelationshipsForOldValue: oldValue
	                                          newValue: newValue
                             ofPropertyWithDescription: propertyDesc];

	[self markAsUpdatedIfNeededForProperty: key];	
	[super didChangeValueForKey: key];
}

#pragma mark - Collection Mutation with Integrity Check

- (id)collectionForProperty: (NSString *)key insertionIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForStorageKey: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException 
						format: @"Attempt to call addObject:forProperty: for %@ "
			                     "which is not a multivalued property of %@",
			                     key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]
		   || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException 
						format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException
						format: @"Attempt to call insertObject:atIndex:forProperty: "
			                     "for %@ which is not an ordered multivalued property of %@",
			                     key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForStorageKey: key] mutableCopy];
	id collection = [self collectionForProperty: key insertionIndex: index];

	[self willChangeValueForProperty: key];
	[collection insertObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

- (id)collectionForProperty: (NSString *)key removalIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForStorageKey: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Attempt to call removeObject:forProperty: for "
			                     "%@ which is not a multivalued property of %@",
			                     key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]
		   || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Attempt to call removeObject:atIndex:forProperty: "
			                     "for %@ which is not an ordered multivalued property of %@",
			                     key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForStorageKey: key] mutableCopy];
	id collection = [self collectionForProperty: key removalIndex: index];

	[self willChangeValueForProperty: key];
	[collection removeObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

- (void) validateMultivaluedPropertiesUsingMetamodel
{
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		/* At validation time, derived properties should return a valid collection */
		if ([propDesc isMultivalued] == NO)
			continue;

		Class class = [self collectionClassForPropertyDescription: propDesc];
		/* We must access the instance variable or the primitive value, and we 
		   cannot use -valueForProperty:, because getters tend to return 
		   defensive copies (immutable collections). */
		id collection = [self valueForStorageKey: [propDesc name]];

		if ([collection isKindOfClass: class] == NO)
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"Property %@ of %@ is declared as a collection "
			                     "in the metamodel but the value class is %@ and "
			                     "doesn't match the requirements.",
			                    [propDesc name], self, [collection class]];
		}
	}
}

#pragma mark - Overridable Notifications

// TODO: Change to new -didAwaken method called in a predetermined order
- (void)awakeFromFetch
{
    [self validateMultivaluedPropertiesUsingMetamodel];
}

- (void)willLoad
{
	ETAssert(_variableStorage == nil);
	_variableStorage = [self newVariableStorage];
    _outgoingSerializedRelationshipCache = [self newOutgoingRelationshipCache];
    _incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
}

- (void)didLoad
{
	
}

- (void)didReload
{

}

#pragma mark - Hash and Equality

- (NSUInteger)hash
{
	return [_UUID hash] ^ 0x39ab6f39b15233de;
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
	if ([[anObject UUID] isEqual: _UUID])
	{
		return YES;
	}
	return NO;
}

- (BOOL)isTemporallyEqual: (id)anObject
{
	if (anObject == self)
	{
		return YES;
	}
	if (![anObject isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[anObject UUID] isEqual: _UUID] && [[anObject revision] isEqual: [self revision]])
	{
		return YES;
	}
	return NO;
}

#pragma mark - Object Matching

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	// TODO: Check and traverse relationships to visit the object graph
	return ([[aQuery predicate] evaluateWithObject: self] ? A(self) : [NSArray array]);
}

#pragma mark - Description

static int indent = 0;

- (NSString *)detailedDescription
{
	if (_inDescription)
	{
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _UUID];
	}
	_inDescription = YES;
	indent++;
	NSMutableString *str = [NSMutableString stringWithFormat: @"<%@(%@) at %p UUID %@ data: {\n",  [[self entityDescription] name], NSStringFromClass([self class]), self, _UUID];
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
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _UUID];
	}
	
	_inDescription = YES;
	NSString *desc = [NSString stringWithFormat: @"<%@(%@) %p UUID=%@ properties=%@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _UUID, [self propertyNames]];

	_inDescription = NO;
	return desc;
}

- (NSString *)typeDescription
{
	return [[self entityDescription] localizedDescription];
}

- (NSString *)revisionDescription
{
	return [[self revision] description];
}

- (NSString *)tagDescription
{
	return [(NSArray *)[[[self tags] mappedCollection] tagString] componentsJoinedByString: @", "];
}

#pragma mark - Framework Private

- (CORelationshipCache *)incomingRelationshipCache
{
    return _incomingRelationshipCache;
}

- (COCrossPersistentRootReferenceCache *)crossReferenceCache
{
    return [[_objectGraphContext editingContext] crossReferenceCache];
}

/**
 * Cross persistent root references can become invalid, if other persistent 
 * roots undergo a state switch (current revision change, branch switch etc.).
 *
 * An invalid reference points either to:
 * - an outdated instance (although COObject are reused if loaded in memory)
 * - a past object (or deleted object)
 * - a future object (an object that doesn't exist yet in the current state)
 *
 * Calling -updateCrossPersistentRootReferences on every state switch ensures 
 * the outdated instance case never occurs. CoreObject does it, so the problem 
 * shouldn't arise.
 *
 * For a persistent root state switch, we use 
 * -valueForSerializedValue:ofType:propertyDescription: to recreate each 
 * persistent outgoing relationship in the receiver. This deserialization method 
 * will hide or skip objects that corresponds to UUID or COPath elements that 
 * cannot be resolved in the editing context (because their corresponding object 
 * doesn't exist yet or has been deleted in the currently loaded state).
 */
- (void) updateCrossPersistentRootReferences
{
    for (NSString *key in [_outgoingSerializedRelationshipCache allKeys])
    {
        ETPropertyDescription *propDesc = [[self entityDescription] propertyDescriptionForName: key];
		ETAssert([propDesc isPersistent]);

		// HACK
		COType collectionType = ([propDesc isOrdered] ? kCOTypeArray : kCOTypeSet);
        COType type = kCOTypeReference | ([propDesc isMultivalued] ? collectionType : 0);

		id serializedValue = [_outgoingSerializedRelationshipCache objectForKey: key];
        id value = [self valueForSerializedValue: serializedValue
		                                  ofType: type
		                     propertyDescription: propDesc];
        
        // N.B., we need to set this in a way that doesn't cause us to recalculate
		// and overwrite the version stored in _outgoingSerializedRelationshipCache
        [self setValue: value forStorageKey: key];
    }
}

- (void) markAsRemovedFromContext
{
    // TODO: Turn the object into a kind of zombie
}

@end
