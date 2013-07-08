#import "CORelationshipCache.h"
#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/Macros.h>
#import "COType.h"
#import "COItem.h"

@interface COCachedRelationship : NSObject
{
@public
    NSString *_targetProperty;
    /**
     * Weak reference.
     */
    COObject *_sourceObject;
    NSString *_sourceProperty;
}

@property (readwrite, nonatomic, assign) COObject *sourceObject;
@property (readwrite, nonatomic, copy) NSString *sourceProperty;
@property (readwrite, nonatomic, copy) NSString *targetProperty;

@end

@implementation COCachedRelationship

@synthesize sourceObject = _sourceObject;
@synthesize sourceProperty = _sourceProperty;
@synthesize targetProperty = _targetProperty;

- (void) dealloc
{
    [_sourceProperty release];
    [_targetProperty release];
    [super dealloc];
}

@end

@implementation CORelationshipCache

#define INITIAL_ARRAY_CAPACITY 8

- (id) init
{
    SUPERINIT;
    _cachedRelationships = [[NSMutableArray alloc] initWithCapacity: INITIAL_ARRAY_CAPACITY];
    return self;
}

- (void) dealloc
{
    [_cachedRelationships release];
    [super dealloc];
}

- (NSSet *) referringObjectsForPropertyInTarget: (NSString *)aProperty
{
    NSMutableSet *result = [NSMutableSet set];
    for (COCachedRelationship *entry in _cachedRelationships)
    {
        if ([aProperty isEqualToString: entry->_targetProperty])
        {
            [result addObject: entry->_sourceObject];
        }
    }
    return result;
}

- (COObject *) referringObjectForPropertyInTarget: (NSString *)aProperty
{
    for (COCachedRelationship *entry in _cachedRelationships)
    {
        if ([aProperty isEqualToString: entry->_targetProperty])
        {
            return entry->_sourceObject;
        }
    }
    return nil;
}

- (void) removeAllEntries
{
    [_cachedRelationships removeAllObjects];
}

- (void) removeReferencesForPropertyInTarget: (NSString *)aTargetProperty
{
    NSUInteger count = [_cachedRelationships count];
    for (NSUInteger i = 0; i<count; i++)
    {
        COCachedRelationship *entry = [_cachedRelationships objectAtIndex: i];
        if ([aTargetProperty isEqualToString: entry->_targetProperty])
        {
            [_cachedRelationships removeObjectAtIndex: i];
            i++;
        }
    }
}

- (void) removeReferencesForPropertyInSource: (NSString *)aTargetProperty
{
    NSUInteger count = [_cachedRelationships count];
    for (NSUInteger i = 0; i<count; i++)
    {
        COCachedRelationship *entry = [_cachedRelationships objectAtIndex: i];
        if ([aTargetProperty isEqualToString: entry->_sourceProperty])
        {
            [_cachedRelationships removeObjectAtIndex: i];
            i++;
        }
    }
}

- (void) removeReferencesForSourceObject: (COObject *)anObject
{
    NSUInteger count = [_cachedRelationships count];
    for (NSUInteger i = 0; i<count; i++)
    {
        COCachedRelationship *entry = [_cachedRelationships objectAtIndex: i];
        if (anObject == entry->_sourceObject)
        {
            [_cachedRelationships removeObjectAtIndex: i];
            i++;
        }
    }
}

- (void) addReferenceFromSourceObject: (COObject *)aReferrer
                       sourceProperty: (NSString *)aSource
                       targetProperty: (NSString *)aTarget
{
    COCachedRelationship *record = [[COCachedRelationship alloc] init];
    record.sourceObject = aReferrer;
    record.sourceProperty = aSource;
    record.targetProperty = aTarget;
    [_cachedRelationships addObject: record];
    [record release];
}

@end
