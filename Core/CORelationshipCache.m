/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import "CORelationshipCache.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import "COType.h"
#import "COItem.h"
#import "COObject.h"
#import "COObject+Private.h"
#import "COObjectGraphContext+Private.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

@implementation COCachedRelationship

@synthesize sourceObject = _sourceObject;
@synthesize sourceProperty = _sourceProperty;
@synthesize targetProperty = _targetProperty;

- (NSDictionary *)descriptionDictionary
{
	return @{ @"property": _targetProperty != nil ? _targetProperty : @"nil",
	         @"opposite property": _sourceProperty,
	        @"opposite object": _sourceObject.UUID };
}

- (NSString *)description
{
	return self.descriptionDictionary.description;
}

- (BOOL) isSourceObjectTrackingSpecificBranchForTargetObject: (COObject *)aTargetObject
{
	if (_sourceObject.objectGraphContext == aTargetObject.objectGraphContext)
	{
		return NO;
	}
	return _sourceObject.objectGraphContext.trackingSpecificBranch;
}

- (BOOL)isSourceObjectBranchDeleted
{
	return _sourceObject.persistentRoot.deleted || _sourceObject.branch.deleted;
}

@end

@implementation CORelationshipCache

#define INITIAL_ARRAY_CAPACITY 8

- (instancetype) initWithOwner: (COObject *)owner
{
	NILARG_EXCEPTION_TEST(owner);
    SUPERINIT;
    _cachedRelationships = [[NSMutableArray alloc] initWithCapacity: INITIAL_ARRAY_CAPACITY];
    _owner = owner;
    return self;
}

- (instancetype)init
{
	return [self initWithOwner: nil];
}

- (NSString *)description
{
	NSArray *relationships =
		(id)[[_cachedRelationships mappedCollection] descriptionDictionary];
	return @{ @"owner": _owner.UUID, @"relationships": relationships }.description;
}

- (NSSet *) referringObjectsForPropertyInTarget: (NSString *)aProperty
{
    NSMutableSet *result = [NSMutableSet set];
    for (COCachedRelationship *entry in _cachedRelationships)
    {
		/* i.e., hide incoming references that _come from_ specific (non-current) branches
		   (regardless of whether they are specifc-branch or current-branch references) 
		 
		   On slide 1 of 'cross persistent root reference semantics.key',
		   this corresponds to John (A) and Lucy (A) hiding the dotted incoming references from
		   Group (B). */
		if ([entry isSourceObjectTrackingSpecificBranchForTargetObject: _owner])
			continue;

		if (entry.sourceObjectBranchDeleted)
			continue;
		
        if ([aProperty isEqualToString: entry->_targetProperty])
        {
            [result addObject: entry->_sourceObject];
        }
    }
	
	/* If this is an object on a specific branch, pretend that incoming references
	   for the root objcet on the current branch graph are pointing at us.

	   On slide 2 of 'cross persistent root reference semantics.key',
	   this corresponds to the non-current branch Lucy (A) viewing the dotted incoming references from
	   Group (A). */
	if (_owner.objectGraphContext.trackingSpecificBranch)
	{
		COObject *currentBranchRootObject = _owner.persistentRoot.rootObject;
		NSSet *referringObjectsToCurrentBranch = [currentBranchRootObject.incomingRelationshipCache referringObjectsForPropertyInTarget: aProperty];		
		[result unionSet: referringObjectsToCurrentBranch];
	}
	
    return result;
}

- (NSSet *) referringObjects
{
    NSMutableSet *result = [NSMutableSet set];
    for (COCachedRelationship *entry in _cachedRelationships)
    {
		/* When deallocating an object graph and replacing references to its
		   inner objects with -[COPath brokenPath], some of them might be 
		   already deallocated. */
		if (entry->_sourceObject == nil)
			continue;

		// N.B.: Don't filter by !isSourceObjectTrackingSpecificBranch as the other methods do
		[result addObject: entry->_sourceObject];
    }
    return result;
}

- (COObject *) referringObjectForPropertyInTarget: (NSString *)aProperty
{
    NSMutableArray *results = [NSMutableArray array];
    
    for (COCachedRelationship *entry in _cachedRelationships)
    {
		if ([entry isSourceObjectTrackingSpecificBranchForTargetObject: _owner])
			continue;

        if ([aProperty isEqualToString: entry->_targetProperty])
        {
            [results addObject: entry->_sourceObject];
        }
    }
    
    assert(results.count == 0
           || results.count == 1);
    
    if (results.count == 0)
    {
        return nil;
    }
    return results.firstObject;
}

- (void) removeAllEntries
{
    [_cachedRelationships removeAllObjects];
}

- (NSArray *) allEntries
{
	return _cachedRelationships;
}

- (void) removeReferencesForPropertyInSource: (NSString *)aTargetProperty
                                sourceObject: (COObject *)anObject
{
    // FIXME: Ugly, rewrite
    
    NSUInteger i = 0;
    while (i < _cachedRelationships.count)
    {
        COCachedRelationship *entry = _cachedRelationships[i];
        if ([aTargetProperty isEqualToString: entry->_sourceProperty]
            && entry.sourceObject == anObject)
        {
            [_cachedRelationships removeObjectAtIndex: i];
        }
        else
        {
            i++;
        }
    }
}

- (void) addReferenceFromSourceObject: (COObject *)aReferrer
                       sourceProperty: (NSString *)aSource
                       targetProperty: (NSString *)aTarget
{
    ETPropertyDescription *prop = [_owner.entityDescription propertyDescriptionForName: aTarget];
    if (!prop.multivalued)
    {
        // We are setting the value of a non-multivalued property, so assert
        // that it is currently not already set.
        
        // HACK: The assertion fails when code uses -didChangeValueForProperty:
        // instead of -didChangeValueForProperty:oldValue:, because we can't clear the old
        // relationships from the cache if -didChangeValueForProperty: is used.
        //
        // So the assetion was removed and this hack added to remove stale entries from
        // the cache, only for one-many relationships. 
        for (COCachedRelationship *entry in [NSArray arrayWithArray: _cachedRelationships])
        {
            if ([aTarget isEqualToString: entry->_targetProperty])
            {
                [_cachedRelationships removeObject: entry];
            }
        }
    }
    
    COCachedRelationship *record = [[COCachedRelationship alloc] init];
    record.sourceObject = aReferrer;
    record.sourceProperty = aSource;
    record.targetProperty = aTarget;
    [_cachedRelationships addObject: record];
}

@end
