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

	ETPropertyDescription *nameProperty = 
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"Anonymous.NSString"];
	// TODO: Declare as a transient property... ETLayoutItem overrides it to be 
	// a persistent property.
	//ETPropertyDescription *idProperty = 
	//	[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"Anonymous.NSString"];
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
	[tagsProperty setOrdered: YES];

	NSArray *transientProperties = A(displayNameProperty, lastVersionDescProperty, tagDescProperty, typeDescProperty);
#ifndef GNUSTEP
	transientProperties = [transientProperties arrayByAddingObject: iconProperty];
#endif
	NSArray *persistentProperties = A(nameProperty, tagsProperty);

	[[persistentProperties mappedCollection] setPersistent: YES];
	[object setPropertyDescriptions: [transientProperties arrayByAddingObjectsFromArray: persistentProperties]];

	return object;
}

#pragma mark - Initialization

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

		id collection = nil;

		if ([propDesc isKeyed])
		{
			if ([propDesc isPersistent])
			{
				collection = [[CODictionary alloc] initWithObjectGraphContext: _objectGraphContext];
			}
			else
			{
				collection = [NSMutableDictionary dictionary];
			}
		}
		else
		{
			collection = ([propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set]);
		}
		
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

		id collection = ([propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set]);

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
    _relationshipsAsCOPathOrETUUID = [self newOutgoingRelationshipCache];
	_relationshipCache = [[CORelationshipCache alloc] initWithOwner: self];

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
        newObject->_relationshipsAsCOPathOrETUUID = [self newOutgoingRelationshipCache];
        newObject->_relationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
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
	return [self primitiveValueForKey: @"name"];
}

- (NSString *)identifier
{
	return [self name];
}

- (void)setName: (NSString *)aName
{
	[self willChangeValueForProperty: @"name"];
	[self setPrimitiveValue: aName forKey: @"name"];
	[self didChangeValueForProperty: @"name"];
}

- (NSArray *)tags
{
	return [self primitiveValueForKey: @"tags"];
}

#pragma mark - Property-Value Coding

- (NSSet *) observableKeyPaths
{
	return S(@"name", @"revisionDescription", @"tagDescription");
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
		[NSException raise: NSInvalidArgumentException
					format: @"Tried to get value for invalid property %@", key];
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
			assert([[value persistentRoot] parentContext] == [[self persistentRoot] parentContext]);
		}    
	}
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	/* We call the setter directly if implemented */

	NSString *setterName = [NSString stringWithFormat: @"set%@:", [key stringByCapitalizingFirstLetter]];
	SEL setter = NSSelectorFromString(setterName);

	if ([self respondsToSelector: setter])
	{
		// NOTE: Don't use -performSelector:withObject: because it doesn't
		// support unboxing scalar values as Key-Value Coding does.
		[self setValue: value forKey: key];
		return YES;
	}

	/* Otherwise we do the integrity check, update the variable storage, and 
	   trigger the change notifications */

	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
		return NO;
	}
    
    [self setValue: value forPropertyWithoutSetter: key];

	return YES;
}

- (void) setValue: (id)value forPropertyWithoutSetter: (NSString *)key
{
	// FIXME: Move this check elsewhere or rework it because it can break on
	// transient values or archived objects such as NSColor, NSView.
	//if (![COObject isCoreObjectValue: value])
	//{
	//	[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	//}

 	BOOL isMultivalued = [[[self entityDescription] propertyDescriptionForName: key] isMultivalued];
    
    if (isMultivalued)
    {
        if (([value isKindOfClass: [NSArray class]] && ![value isKindOfClass: [NSMutableArray class]]))
        {
            value = [NSMutableArray arrayWithArray: value];
        }
        else if (([value isKindOfClass: [NSSet class]] && ![value isKindOfClass: [NSMutableSet class]]))
        {
            value = [NSSet setWithSet: value];
        }
    }
    
	id oldValue = [self valueForProperty: key];
	 
    oldValue = (isMultivalued ? [oldValue mutableCopy] : oldValue);

	[self checkEditingContextForValue: value];

	[self willChangeValueForProperty: key];
	[self setPrimitiveValue: value forKey: key];
	[self didChangeValueForProperty: key oldValue: oldValue];
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

#pragma mark - Direct Access to the Variable Storage

- (id)primitiveValueForKey: (NSString *)key
{
    ETPropertyDescription *propDesc = [[self entityDescription] propertyDescriptionForName: key];

    // Special case for searching the relationship cache
    if (![propDesc isPersistent]
        && (nil != [propDesc opposite])
        && ([[propDesc opposite] isPersistent]))
    {
        if ([propDesc isMultivalued])
        {
            NSSet *results = [_relationshipCache referringObjectsForPropertyInTarget: key];
            
            return results;
        }
        COObject *result = [_relationshipCache referringObjectForPropertyInTarget: key];
        return result;
    }

	id value = [_variableStorage objectForKey: key];
	return (value == [NSNull null] ? nil : value);
}

- (void)setPrimitiveValue: (id)value forKey: (NSString *)key
{
	[_variableStorage setObject: (value == nil ? [NSNull null] : value)
						 forKey: key];
}

// FIXME: Investigate whether this way of implementing KVC is really KVC compliant
- (id)valueForUndefinedKey: (NSString *)key
{
	return [self primitiveValueForKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
	[self setPrimitiveValue: value forKey: key];
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

- (void)didChangeValueForProperty: (NSString *)key oldValue: (id)oldValue
{
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    
	// TODO: Evaluate whether -checkEditingContextForValue: is too costly
	//[self checkEditingContextForValue: [self valueForProperty: key]];
    
    id originalRelationships = [_relationshipsAsCOPathOrETUUID objectForKey: key];
    if (originalRelationships != nil)
    {
		// TODO: Use -serializedValueForProperty: instead of
		// -serializedValueForValue:.
		id currentValue = [self valueForProperty: key];

        // Re-serialize the current value from COObject to ETUUID/COPath
        
        id serializedValue = [self serializedValueForValue: currentValue];
        
        //NSLog(@"_relationshipsAsCOPathOrETUUID: setting %@ from %@ to %@", key,
        //     [_relationshipsAsCOPathOrETUUID objectForKey: key], serializedValue);
        
        [_relationshipsAsCOPathOrETUUID setObject: serializedValue
                                           forKey: key];
    }
    
    // Remove objects in newValue from their old parents
    // as perscribed by the COEditingContext class docs
    // FIXME: Ugly implementation
    if ([propertyDesc isComposite])
    {
        ETPropertyDescription *parentDesc = [propertyDesc opposite];
        id aValue = [self valueForKey: key];
        
        for (COObject *objectBeingInserted in ([propertyDesc isMultivalued] ? aValue : [NSArray arrayWithObject: aValue]))
        {
            COObject *objectBeingInsertedParent = [[objectBeingInserted relationshipCache] referringObjectForPropertyInTarget: [parentDesc name]];
            
            // FIXME: Minor flaw, you can insert a composite twice if the collection is ordered.
            // e.g.
            // (a, b, c) => (a, b, c, a) since we only remove the objects from their old parents if the
            // parent is different than the object we're inserting into
            
            if (objectBeingInsertedParent != nil && objectBeingInsertedParent != self)
            {
                BOOL alreadyRemoved = NO;
                
                if (![[objectBeingInsertedParent valueForKey: key] containsObject: objectBeingInserted])
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
    
    [self updateCachedOutgoingRelationshipsForOldValue: oldValue
                                                  newValue: [self valueForKey: key]
                                 ofPropertyWithDescription: [_entityDescription propertyDescriptionForName: key]];
    
	[self markAsUpdatedIfNeededForProperty: key];
	
	[super didChangeValueForKey: key];
}

#pragma mark - Collection Mutation with Integrity Check

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

- (void) validateMultivaluedPropertiesUsingMetamodel
{
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		/* At validation time, derived properties should return a valid collection */
		if ([propDesc isMultivalued] == NO)
			continue;

		Class class = Nil;
		
		if ([propDesc isKeyed])
		{
			class = ([propDesc isPersistent] ? [CODictionary class] : [NSDictionary class]);
		}
		else
		{
			class = ([propDesc isOrdered] ? [NSArray class] : [NSSet class]);
		}

		id collection = nil;

		/* We must access the instance variable or the primitive value, and we 
		   cannot use -valueForKey:, because getters tend to return defensive 
		   copies (immutable collections). */
		if (ETGetInstanceVariableValueForKey(self, &collection, [propDesc name]) == NO)
		{
			collection = [self primitiveValueForKey: [propDesc name]];
		}

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
	assert(_variableStorage == nil);
	_variableStorage = [self newVariableStorage];
    _relationshipsAsCOPathOrETUUID = [self newOutgoingRelationshipCache];
    _relationshipCache = [[CORelationshipCache alloc] initWithOwner: self];
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

- (CORelationshipCache *)relationshipCache
{
    return _relationshipCache;
}

- (COCrossPersistentRootReferenceCache *)crossReferenceCache
{
    return [[_objectGraphContext editingContext] crossReferenceCache];
}

- (void) updateCrossPersistentRootReferences
{
    for (NSString *key in [_relationshipsAsCOPathOrETUUID allKeys])
    {
        id serializedValue = [_relationshipsAsCOPathOrETUUID objectForKey: key];
        ETPropertyDescription *propDesc = [[self entityDescription] propertyDescriptionForName: key];
		ETAssert([propDesc isPersistent]);

        // HACK
        COType type = kCOTypeReference | ([propDesc isMultivalued]
                                          ? ([propDesc isOrdered]
                                             ? kCOTypeArray
                                             : kCOTypeSet)
                                          : 0);
        
        id value = [self valueForSerializedValue: serializedValue ofType: type propertyDescription: propDesc];
        
        // N.B., we need to set this in a way that doesn't cause us to recalculate and overwrite
        // the version stored in _relationshipsAsCOPathOrETUUID
        [_variableStorage setValue: value
                            forKey: key];
    }
}

- (void) markAsRemovedFromContext
{
    // TODO: Turn the object into a kind of zombie
}

@end
