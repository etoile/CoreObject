/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  October 2013
	License:  MIT  (see COPYING)

 */

#import "COObjectGraphContext+GarbageCollection.h"
#import "COObjectGraphContext+Debugging.h"
#import "COObject.h"

@implementation COObjectGraphContext (COGarbageCollection)

/**
 * Given a COObject, returns an array of all of the COObjects directly reachable
 * from that COObject.
 */
static NSArray *DirectlyReachableObjectsFromObject(COObject *anObject, COObjectGraphContext *restrictToObjectGraph)
{
	NSMutableArray *result = [NSMutableArray array];
	for (ETPropertyDescription *propDesc in [[anObject entityDescription] allPropertyDescriptions])
	{
		if (![propDesc isPersistent])
		{
			continue;
		}
		
		NSString *propertyName = [propDesc name];
		id value = [anObject valueForKey: propertyName];
        
        if ([propDesc isMultivalued])
        {
			if ([propDesc isKeyed])
			{
				assert([value isKindOfClass: [NSDictionary class]]);
			}
			else
			{
				assert([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]);
				
			}
			
			/* We use -objectEnumerator, because subvalue can be a  CODictionary
			 or a NSDictionary (if a getter exists to expose the CODictionary
			 as a NSDictionary for UI editing) */
            for (id subvalue in [value objectEnumerator])
            {
                if ([subvalue isKindOfClass: [COObject class]]
					&& [subvalue objectGraphContext] == restrictToObjectGraph)
                {
                    [result addObject: subvalue];
                }
            }
        }
        else
        {
            if ([value isKindOfClass: [COObject class]]
				&& [value objectGraphContext] == restrictToObjectGraph)
            {
                [result addObject: value];
            }
            // Ignore non-COObject objects
        }
	}
	return result;
}

static void FindReachableObjectsFromObject(COObject *anObject, NSMutableSet *collectedUUIDSet, COObjectGraphContext *restrictToObjectGraph)
{
    ETUUID *uuid = [anObject UUID];
    if ([collectedUUIDSet containsObject: uuid])
    {
        return;
    }
    [collectedUUIDSet addObject: uuid];
    
    // Call recursively on all composite and referenced objects
    for (COObject *obj in DirectlyReachableObjectsFromObject(anObject, restrictToObjectGraph))
    {
        FindReachableObjectsFromObject(obj, collectedUUIDSet, restrictToObjectGraph);
    }
}

- (NSSet *) allReachableObjectUUIDs
{
	NSParameterAssert([self rootObject] != nil);
	
	NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity: [_loadedObjects count]];
	FindReachableObjectsFromObject([self rootObject], result, self);
	return result;
}

#pragma mark - cycle detection

static void FindCyclesInContainersOfObject(COObject *currentObject, COObject *objectBeingSearchedFor)
{
	for (ETPropertyDescription *propDesc in [[currentObject entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isContainer])
		{
			NSString *propertyName = [propDesc name];
			COObject *container = [currentObject valueForKey: propertyName];
			
			if (container == objectBeingSearchedFor)
				[NSException raise: NSGenericException format: @"Cycle detected"];
			
			if (container != nil)
				FindCyclesInContainersOfObject(container, objectBeingSearchedFor);
		}
	}
}

- (void) checkForCyclesInCompositeRelationshipsFromObject: (COObject*)anObject
{
	FindCyclesInContainersOfObject(anObject, anObject);
}

- (void) checkForCyclesInCompositeRelationshipsInObjects: (NSArray *)objects
{
	for (COObject *object in objects)
	{
		[self checkForCyclesInCompositeRelationshipsFromObject: object];
	}
}

- (void) checkForCyclesInCompositeRelationshipsInChangedObjects
{
	[self checkForCyclesInCompositeRelationshipsInObjects: [self changedObjects]];
}

@end
