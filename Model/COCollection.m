/*
    Copyright (C) 2011 Quentin Mathe

    Date:  December 2011
    License:  MIT  (see COPYING)
 */

#import "COCollection.h"
#import "COEditingContext.h"
#import "COObjectGraphContext.h"
#import "COObject+Private.h"
#import "COPersistentRoot.h"

@implementation COCollection

+ (void)initialize
{
    if (self != [COCollection class])
        return;

    [self applyTraitFromClass: [ETCollectionTrait class]];
    [self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (ETPropertyDescription *)contentPropertyDescriptionWithName: (NSString *)aName
                                                         type: (NSString *)aType
                                                     opposite: (NSString *)oppositeType
{
    ETPropertyDescription *contentProperty =
        [ETPropertyDescription descriptionWithName: aName typeName: aType];
    contentProperty.multivalued = YES;
    contentProperty.opposite = (id)oppositeType;
    contentProperty.ordered = YES;
    contentProperty.persistent = YES;
    return contentProperty;
}

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *collection = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add the 
    // property descriptions that we will inherit through the parent
    if (![collection.name isEqual: [COCollection className]])
        return collection;

    return collection;
}

- (instancetype)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
    if ([[self class] isEqual: [COCollection class]])
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to initialize abstract class %@", [self class]];
    }

    self = [super initWithObjectGraphContext: aContext];
    if (self == nil)
        return nil;

    ETEntityDescription *coreObjectEntity =
        [aContext.modelDescriptionRepository entityDescriptionForClass: [COObject class]];

    // NOTE: COCollection is abstract, so subclasses uses either COObject or
    // a COCollection subentity.
    if (![self.entityDescription isEqual: coreObjectEntity]
        && [self.entityDescription propertyDescriptionForName: self.contentKey] == nil)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Found no property description for -contentKey %@", self.contentKey];
    }
    return self;
}

- (ETUTI *)objectType
{
    ETPropertyDescription *propertyDesc =
        [self.entityDescription propertyDescriptionForName: self.contentKey];
    ETModelDescriptionRepository *repo = self.persistentRoot.editingContext.modelDescriptionRepository;

    return [ETUTI typeWithClass: [repo classForEntityDescription: propertyDesc.type]];
}

- (void)addObjects: (NSArray *)anArray
{
    for (id object in anArray)
    {
        [self addObject: object];
    }
}

- (void)didLoadObjectGraph
{
    [self didUpdate];
}

- (void)didUpdate
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (NSString *)contentKey
{
    return @"objects";
}

- (BOOL)isOrdered
{
    // TODO: If too slow, return the boolean directly.
    return [self.entityDescription propertyDescriptionForName: self.contentKey].ordered;
}

- (id)content
{
    return [self valueForVariableStorageKey: self.contentKey];
}

- (NSArray *)contentArray
{
    return [[self valueForProperty: self.contentKey] contentArray];
}

- (void)insertObjects: (NSArray *)objects atIndexes: (NSIndexSet *)indexes hints: (NSArray *)hints
{
    id collection = [self collectionForProperty: self.contentKey mutationIndexes: indexes];

    [self willChangeValueForProperty: self.contentKey
                           atIndexes: indexes
                         withObjects: objects
                        mutationKind: ETCollectionMutationKindInsertion];

    [collection insertObjects: objects atIndexes: indexes hints: hints];

    [self didChangeValueForProperty: self.contentKey
                          atIndexes: indexes
                        withObjects: objects
                       mutationKind: ETCollectionMutationKindInsertion];
}

- (void)removeObjects: (NSArray *)objects atIndexes: (NSIndexSet *)indexes hints: (NSArray *)hints
{
    id collection = [self collectionForProperty: self.contentKey mutationIndexes: indexes];

    [self willChangeValueForProperty: self.contentKey
                           atIndexes: indexes
                         withObjects: objects
                        mutationKind: ETCollectionMutationKindRemoval];

    [collection removeObjects: objects atIndexes: indexes hints: hints];

    [self didChangeValueForProperty: self.contentKey
                          atIndexes: indexes
                        withObjects: objects
                       mutationKind: ETCollectionMutationKindRemoval];
}

- (id)objectForIdentifier: (NSString *)anId
{
    for (id object in self.content)
    {
        if ([[object identifier] isEqualToString: anId])
        {
            return object;
        }
    }
    return nil;
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
    NSMutableArray *result = [NSMutableArray array];

    for (COObject *object in self.content)
    {
        if ([aQuery.predicate evaluateWithObject: object])
        {
            [result addObject: object];
        }
    }

    return result;
}

@end


@implementation COObject (COCollectionTypeQuerying)

- (BOOL)isGroup
{
    return NO;
}

- (BOOL)isTag
{
    return NO;
}

- (BOOL)isContainer
{
    return NO;
}

- (BOOL)isLibrary
{
    return NO;
}

@end

