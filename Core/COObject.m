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
#import "COAttachmentID.h"
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
	[UUID setReadOnly: YES];
	ETPropertyDescription *isPersistent =
		[ETPropertyDescription descriptionWithName: @"isPersistent" type: (id)@"BOOL"];
	[isPersistent setDerived: YES];
	ETPropertyDescription *isRoot =
		[ETPropertyDescription descriptionWithName: @"isRoot" type: (id)@"BOOL"];
	[isRoot setDerived: YES];
	ETPropertyDescription *isShared =
		[ETPropertyDescription descriptionWithName: @"isShared" type: (id)@"BOOL"];
	[isShared setReadOnly: YES];

	/* Basic Properties */

	ETPropertyDescription *name =
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"NSString"];
	ETPropertyDescription *identifier =
		[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"NSString"];
	ETPropertyDescription *tags  =
		[ETPropertyDescription descriptionWithName: @"tags" type: (id)@"COTag"];
	[tags setMultivalued: YES];

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
	[displayName setDisplayName: _(@"Name")];

	/* Description Properties */

	ETPropertyDescription *revisionDescription =
		[ETPropertyDescription descriptionWithName: @"revisionDescription" type: (id)@"NSString"];
	[revisionDescription setDisplayName: _(@"Version")];
	ETPropertyDescription *tagDescription =
		[ETPropertyDescription descriptionWithName: @"tagDescription" type: (id)@"NSString"];
	[tagDescription setDisplayName: _(@"Tags")];
	ETPropertyDescription *typeDescription =
		[ETPropertyDescription descriptionWithName: @"typeDescription" type: (id)@"NSString"];
	[typeDescription setDisplayName: _(@"Type")];

	NSArray *transientProperties = A(UUID, isPersistent, isRoot, identifier,
		displayName, revisionDescription, tagDescription, typeDescription, tags);
#ifndef GNUSTEP
	transientProperties = [transientProperties arrayByAddingObject: icon];
#endif
	NSArray *persistentProperties = A(isShared, name);
	NSArray *properties =
		[transientProperties arrayByAddingObjectsFromArray: persistentProperties];

	[[[properties arrayByRemovingObject: name] mappedCollection] setReadOnly: YES];
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
	
	if (![anEntityDescription isKindOfEntity: [repo descriptionForName: @"Anonymous.COObject"]])
	{
		[NSException raise: NSInvalidArgumentException
					format: @"The COObject class only supports entitiy descriptions that "
							"are subentities of COObject, but %@ is not.",
							[anEntityDescription fullName]];
	}
}

- (id)prepareWithUUID: (ETUUID *)aUUID
    entityDescription: (ETEntityDescription *)anEntityDescription
   objectGraphContext: (COObjectGraphContext *)aContext
                isNew: (BOOL)inserted  __attribute__((objc_method_family(init)))
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anEntityDescription);
	NILARG_EXCEPTION_TEST(aContext);
	INVALIDARG_EXCEPTION_TEST(aContext, [aContext isKindOfClass: [COObjectGraphContext class]]);

	[self validateEntityDescription: anEntityDescription
	   inModelDescriptionRepository: [aContext modelRepository]];

	SUPERINIT;

	_UUID = aUUID;
	_entityDescription =  anEntityDescription;
	_objectGraphContext = aContext;
	_isPrepared = YES;
	_variableStorage = [self newVariableStorage];
    _outgoingSerializedRelationshipCache = [self newOutgoingRelationshipCache];
	_incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
	_oldValues = [NSMutableArray new];

	[_objectGraphContext registerObject: self isNew: inserted];

	return self;
}

- (id)initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	/* We execute overriden initializer implementations e.g. 
	   -[ETShape initWithBezierPath:objectGraphContext:], until reaching the 
	   topmost COObject designed initializer (aka -[COObject initWithGraphContext:]), 
	   where we return immediately when the basic initialization is done 
	   (this happens when -initWithEntityDescription:objectGraphContext: is used). */
	if (_isPrepared)
		return self;

	NILARG_EXCEPTION_TEST(aContext);

	ETModelDescriptionRepository *repo = [aContext modelRepository];
	return [self prepareWithUUID: [ETUUID UUID]
	           entityDescription: [repo entityDescriptionForClass: [self class]]
	          objectGraphContext: aContext
	                       isNew: YES];
}

- (id)init
{
	return [self initWithObjectGraphContext: nil];
}

- (id)initWithEntityDescription: (ETEntityDescription *)anEntityDesc
             objectGraphContext: (COObjectGraphContext *)aContext
{
	self = [self prepareWithUUID: [ETUUID UUID]
	           entityDescription: anEntityDesc
	          objectGraphContext: aContext
	                       isNew: YES];

	/* For subclasses that override the designated initializer */
	self = [self initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	return self;
}

// TODO: Maybe add convenience copying method, - (COObject *) copyWithCopier: (COCopier *)aCopier
// where the copier stores the state relating to copying, e.g. which context to copy into.

// TODO: Migrate EtoileUI to COCopier and remove. COObject should not respond to
// -copyWithZone:
- (id) copyWithZone: (NSZone *)aZone
{
	COObject *newObject = [[self class] allocWithZone: aZone];
	
	newObject->_UUID = [[ETUUID alloc] init];
	newObject->_entityDescription = _entityDescription;
	newObject->_objectGraphContext = _objectGraphContext;
	newObject->_variableStorage = [self newVariableStorage];
	newObject->_outgoingSerializedRelationshipCache = [self newOutgoingRelationshipCache];
	newObject->_incomingRelationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
	newObject->_oldValues = [NSMutableArray new];

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

- (BOOL) isShared
{
	return YES;
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

- (NSSet *)tags
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

- (BOOL)isCoreObjectValue: (id)value
{  
	return ([value isKindOfClass: [COObject class]]
		 || [value isKindOfClass: [COAttachmentID class]]
	     || [self isSerializablePrimitiveValue: value]
	     || [self isSerializableScalarValue: value]
		 || value == nil);
}

- (BOOL)isEditingContextValidForObject: (COObject *)value
{
	COEditingContext *valueEditingContext = [[value persistentRoot] parentContext];
	COEditingContext *currentEditingContext = [[self persistentRoot] parentContext];
	BOOL involvesTransientObject = (valueEditingContext == nil || currentEditingContext == nil);
	
	return (involvesTransientObject || valueEditingContext == currentEditingContext);
}

- (BOOL)isCoreObjectRelationship: (ETPropertyDescription *)propertyDesc
{
	if ([propertyDesc isPersistent] == NO)
		return NO;

	ETModelDescriptionRepository *repo = [_objectGraphContext modelRepository];
	ETEntityDescription *rootCoreObjectEntity =
		[repo entityDescriptionForClass: [COObject class]];

	return [[propertyDesc type] isKindOfEntity: rootCoreObjectEntity];
}

- (void)validateEditingContextForNewValue: (id)value
                      propertyDescription: (ETPropertyDescription *)propertyDesc
{
	if ([self isCoreObjectRelationship: propertyDesc] == NO)
		return;

	if ([value isPrimitiveCollection])
	{
		ETAssert([propertyDesc isMultivalued]);

		for (COObject *object in [value objectEnumerator])
		{
			ETAssert([self isEditingContextValidForObject: object]);
		}
	}
	else
	{
		ETAssert([self isEditingContextValidForObject: (COObject *)value]);
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

- (NSArray *)validate
{
	return [COError errorsWithValidationResults: [self validateAllValues]];
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
	if ([propDesc opposite] != nil && [propDesc isPersistent] && [[propDesc opposite] isPersistent])
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"For %@, %@ and its opposite are both declared as "
		                     "persistent. For a persistent relationship, "
		                     "CoreObject requires a single side to be declared "
		                     "as persistent.", self, propDesc];
	}

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

- (void)setValue: (id)aValue forVariableStorageKey: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [[self entityDescription] propertyDescriptionForName: key];
    id value = aValue;
	BOOL isPersistentDictionary = ([propertyDesc isKeyed] && [propertyDesc isPersistent]);

    if ([propertyDesc isMultivalued] && isPersistentDictionary == NO)
    {
		value = [aValue mutableCopy];
    }
	
	[_variableStorage setObject: (value == nil ? [NSNull null] : value)
	                     forKey: key];
}

- (id)valueForUndefinedKey: (NSString *)key
{
	return [self valueForVariableStorageKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
	[self willChangeValueForProperty: key];
	[self setValue: value forVariableStorageKey: key];
	[self didChangeValueForProperty: key];
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
	ETPropertyDescription *propertyDesc =
		[_entityDescription propertyDescriptionForName: key];

	if ([propertyDesc isMultivalued] && [self isCoreObjectRelationship: propertyDesc])
	{
		id <ETCollection> oldCollection = [[self valueForStorageKey: key] mutableCopy];

		[_oldValues addObject: [ETKeyValuePair pairWithKey: key
		                                             value: oldCollection]];
	}
	[super willChangeValueForKey: key];
}

- (void) markAsUpdatedIfNeededForProperty: (NSString*)prop
{	
	[_objectGraphContext markObjectAsUpdated: self forProperty: prop];
}

- (void)validateTypeForNewValue: (id)newValue
            propertyDescription: (ETPropertyDescription *)propertyDesc
{
	if ([propertyDesc isPersistent] == NO)
		return;

	if ([self serializationGetterForProperty: [propertyDesc name]] != NULL)
		return;

	if ([newValue isPrimitiveCollection])
	{
		ETAssert([propertyDesc isMultivalued]);

		Class expectedCollectionClass =
			[self collectionClassForPropertyDescription: propertyDesc];

		ETAssert([newValue isKindOfClass: expectedCollectionClass]);

		for (id object in [newValue objectEnumerator])
		{
			ETAssert([self isCoreObjectValue: object]);
		}
	}
	else
	{
		ETAssert([self isCoreObjectValue: newValue]);
	}
}

- (void)validateNewValue: (id)newValue
     propertyDescription: (ETPropertyDescription *)propertyDesc
{
	// NOTE: For the CoreObject benchmark, no visible slowdowns.
	[self validateEditingContextForNewValue: newValue
                        propertyDescription: propertyDesc];
	[self validateTypeForNewValue: newValue
	          propertyDescription: propertyDesc];
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
	// FIXME: In order to make -[TestCrossPersistentRootReferences testPersistentRootUndeletion]
	// work, we will need a different approach to updating _outgoingSerializedRelationshipCache
	//
	// We should preserve references in _outgoingSerializedRelationshipCache that are currently
	// hidden in [self valueForStorageKey: key] (references to deleted persistent roots / branches).
	// This will be complicated to implement, so I'm not sure that hiding broken cross-persistent
	// root references in CoreObject is the right choice; it might be easier to let apps hide them
	// at the UI level.
	
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

/**
 * Removes objects from their old parents (the new parent is the receiver).
 *
 * From a metamodel viewpoint, composite = children (incoming relationship) and
 * container = parent (outgoing relationship).
 *
 * When moving objects into a composite relationship, if they are already 
 * children in another composite relationship, we must remove them from the 
 * previous composite relationship, since objects are limited to a single 
 * parent in such a relationship.
 *
 * If the relationship is a composite (the children are the property value),
 * and a child parent doesn't match the receiver, we remove the child from
 * the children collection owned by its parent.
 *
 * For the inverse relationship (the parent property for each child), we have 
 * nothing to do. COObject manages incoming relationships on our behalf.
 */
- (void)updateCompositeRelationshipForPropertyDescription: (ETPropertyDescription *)propertyDesc
{
    if ([propertyDesc isComposite] == NO)
		return;

	NSString *key = [propertyDesc name];
	ETPropertyDescription *parentDesc = [propertyDesc opposite];
	id value = [self valueForStorageKey: key];
	/* For parent-to-children relationship, just handle to-one or to-many in the same way  */
	id <ETCollection> children =
		([propertyDesc isMultivalued] ? value : [NSArray arrayWithObject: value]);

	for (COObject *child in children)
	{
		/* From the child viewpoint (the child as target), the parent is a referring object */
		COObject *oldParent = [[child incomingRelationshipCache]
				referringObjectForPropertyInTarget: [parentDesc name]];
		
		// FIXME: Minor flaw, you can insert a composite twice if the collection is ordered.
		// e.g.
		// (a, b, c) => (a, b, c, a) since we only remove the objects from their
		// old parents if the parent is different than the object we're inserting into

		if (oldParent == nil || oldParent == self)
			continue;
		
		// FIXME: EtoileUI handles removing the object from its old parent.
		// In that case, don't try to do it ourselves.
		id <ETCollection> oldParentChildren = [oldParent valueForStorageKey: key];
		BOOL alreadyRemoved = (![oldParentChildren containsObject: child]);
		
		if (alreadyRemoved)
			continue;

		[oldParent removeObject: child
		                atIndex: ETUndeterminedIndex
		                   hint: nil
		            forProperty: key];
	}
}

- (id)oldCoreObjectRelationshipValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
	if ([aPropertyDesc isMultivalued] == NO || [self isCoreObjectRelationship: aPropertyDesc] == NO)
		return nil;

	ETKeyValuePair *pair = [_oldValues lastObject];

	if ([[pair key] isEqual: [aPropertyDesc name]] == NO)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"-willChangeValueForProperty: and -didChangeValueForProperty: "
		                     "must be paired in setters. Either "
		                     "-willChangeValueForProperty: was not called for %@ "
		                     "or -didChangeValueForProperty: was not called for %@.",
		                    [aPropertyDesc name], [pair key]];
	}

	[_oldValues removeLastObject];
	return [pair value];
}

- (void)didChangeValueForProperty: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
	id newValue = [self valueForStorageKey: key];
	id oldValue = [self oldCoreObjectRelationshipValueForPropertyDescription: propertyDesc];

	if (propertyDesc == nil)
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Property %@ is not declared in the metamodel %@ for %@",
		                    key, _entityDescription, self];
	}

	[self validateNewValue: newValue propertyDescription: propertyDesc];

	[self updateOutgoingSerializedRelationshipCacheForProperty: key];
	[self updateCompositeRelationshipForPropertyDescription: propertyDesc];
    [self updateCachedOutgoingRelationshipsForOldValue: oldValue
	                                          newValue: newValue
                             ofPropertyWithDescription: propertyDesc];

	[self markAsUpdatedIfNeededForProperty: key];	
	[super didChangeValueForKey: key];
}

#pragma mark - Collection Mutation with Integrity Check

- (id)collectionForProperty: (NSString *)key mutationIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForStorageKey: key];
	Class expectedCollectionClass = [[self collectionClassForPropertyDescription: desc] mutableClass];

	if (!([collection isKindOfClass: expectedCollectionClass]))
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Multivalued property %@ not set up properly in %@. "
		                     "The collection class %@ doesn't match the property "
		                     "description which was requiring %@.",
		                    desc, self, [collection class], expectedCollectionClass];
	}

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException 
						format: @"Attempt to call insertion or mutation methods "
			                     "for %@ which is not a multivalued property of %@",
			                     key, self];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException
						format: @"Attempt to call index-based insertion and "
			                     "removal methods for %@ which is not an ordered "
			                     "multivalued property of %@",
			                     key, self];
		}
	}

	return collection;
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	// NOTE: We validate the entire collection in -didChangeValueForProperty:
	// We could possibly validate just the inserted objects here.
	id collection = [self collectionForProperty: key mutationIndex: index];

	[self willChangeValueForProperty: key];
	[collection insertObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	// NOTE: We validate the entire collection in -didChangeValueForProperty
	// We could possibly validate just the removed objects here.
	id collection = [self collectionForProperty: key mutationIndex: index];

	[self willChangeValueForProperty: key];
	[collection removeObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key];
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

#pragma mark - Overridable Loading Notifications

- (void)awakeFromDeserialization
{
    [self validateMultivaluedPropertiesUsingMetamodel];
}

- (void)didLoadObjectGraph
{
	
}

#pragma mark - Hash and Equality

- (NSUInteger)hash
{
	return [_UUID hash] ^ [[[self persistentRoot] UUID] hash] ^ 0x39ab6f39b15233de;
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
	if ([[anObject UUID] isEqual: _UUID] && [[[anObject persistentRoot] UUID] isEqual: [[self persistentRoot] UUID]])
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

- (NSString *)detailedDescriptionWithTraversalKey: (NSString *)aProperty
{
	NSMutableDictionary *options =
		[D([self propertyNames], kETDescriptionOptionValuesForKeyPaths,
		@"\t", kETDescriptionOptionPropertyIndent) mutableCopy];

	if (aProperty != nil)
	{
		[options setObject: aProperty forKey: kETDescriptionOptionTraversalKey];
	}

	return [self descriptionWithOptions: options];
}

- (NSString *)detailedDescription
{
	return [self detailedDescriptionWithTraversalKey: nil];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"<%@(%@) %p - %@>",
		NSStringFromClass([self class]), [[self entityDescription] name], self, _UUID];
}

- (NSString *)typeDescription
{
	return [[self entityDescription] localizedDescription];
}

- (NSString *)revisionDescription
{
	return [[[self revision] UUID] stringValue];
}

- (NSString *)tagDescription
{
	return [(NSArray *)[[[[self tags] allObjects] mappedCollection] tagString]
		componentsJoinedByString: @", "];
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
