/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  August 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COCrossPersistentRootReferenceCache.h"
#import "COObject.h"

@interface COCrossRefInfo : NSObject

@property (readwrite, nonatomic, weak) COObject *sourceObject;
@property (readwrite, nonatomic, copy) NSString *sourceProperty;
@property (readwrite, nonatomic, copy) ETUUID *tagetPersistentRoot;

@end

@implementation COCrossRefInfo

@synthesize sourceObject, sourceProperty, tagetPersistentRoot;

- (NSString *)description
{
	return [NSString stringWithFormat: @"<COCrossRefInfo from %@ (persistent root %@) : %@ to persistent root %@>",
			[self.sourceObject UUID],
			[[self.sourceObject persistentRoot] UUID],
			sourceProperty,
			tagetPersistentRoot];
}

@end


@implementation COCrossPersistentRootReferenceCache

- (id) init
{
    SUPERINIT;

	// FIXME: For versions prior to 10.8, objects must be explicitly removed
	// from the map table if manual reference couting is used.
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8
	_weakObjectToCrossRefInfoArray = [[NSMapTable alloc] initWithKeyOptions: NSMapTableWeakMemory
#else
	_weakObjectToCrossRefInfoArray = [[NSMapTable alloc] initWithKeyOptions: NSMapTableZeroingWeakMemory
#endif
                                                         valueOptions: NSMapTableStrongMemory
                                                             capacity: 16];
    
    _persistentRootUUIDToCrossRefInfoArray = [[NSMutableDictionary alloc] init];
    
    return self;
}

// TODO: Improve the output
- (NSString *)description
{
	NSMutableString *result = [NSMutableString string];
	for (NSArray *array in [_persistentRootUUIDToCrossRefInfoArray allValues])
	{
		for (COCrossRefInfo *info in array)
		{
			[result appendFormat: @"%@\n", info];
		}
	}
	return result;
}

- (NSArray *) referencedPersistentRootUUIDsForObject: (COObject *)anObject
{
	NSArray *crossRefInfos = [_weakObjectToCrossRefInfoArray objectForKey: anObject];
	
	NSMutableSet *set = [NSMutableSet set];
	for (COCrossRefInfo *info in crossRefInfos)
	{
		[set addObject: info.tagetPersistentRoot];
	}
	return [set allObjects];
}
									  
- (NSArray *) affectedObjectsForChangeInPersistentRoot: (ETUUID *)aPersistentRoot
{
	NSArray *crossRefInfos = [_persistentRootUUIDToCrossRefInfoArray objectForKey: aPersistentRoot];
	
	NSMutableSet *set = [NSMutableSet set];
	for (COCrossRefInfo *info in crossRefInfos)
	{
		[set addObject: info.sourceObject];
	}
	return [set allObjects];
}

- (void) addReferencedPersistentRoot: (ETUUID *)aPersistentRoot
						 forProperty: (NSString *)aProperty
						    ofObject: (COObject *)anObject
{
	COCrossRefInfo *info = [[COCrossRefInfo alloc] init];
	info.sourceObject = anObject;
	info.sourceProperty = aProperty;
	info.tagetPersistentRoot = aPersistentRoot;
	
    {
        NSMutableArray *infos = [_weakObjectToCrossRefInfoArray objectForKey: anObject];
        if (infos == nil)
        {
            infos = [[NSMutableArray alloc] init];
            [_weakObjectToCrossRefInfoArray setObject: infos forKey: anObject];
        }
        [infos addObject: info];
    }

    {
        NSMutableArray *infos = [_persistentRootUUIDToCrossRefInfoArray objectForKey: aPersistentRoot];
        if (infos == nil)
        {
            infos = [[NSMutableArray alloc] init];
            [_persistentRootUUIDToCrossRefInfoArray setObject: infos forKey: aPersistentRoot];
        }
        [infos addObject: info];
    }
}

- (void) clearReferencedPersistentRootsForProperty: (NSString *)aProperty
										  ofObject: (COObject *)anObject
{
	NSMutableArray *infos = [_weakObjectToCrossRefInfoArray objectForKey: anObject];
	for (COCrossRefInfo *info in [infos copy])
	{
		assert(info.sourceObject == anObject);
		if ([info.sourceProperty isEqual: aProperty])
		{
			NSMutableArray *inverseInfos = [_persistentRootUUIDToCrossRefInfoArray objectForKey: info.tagetPersistentRoot];
			for (COCrossRefInfo *inverseInfo in [inverseInfos copy])
			{
				assert([inverseInfo.tagetPersistentRoot isEqual: info.tagetPersistentRoot]);
				if (inverseInfo.sourceObject == anObject &&
					[inverseInfo.sourceProperty isEqual: aProperty])
				{
					[inverseInfos removeObjectIdenticalTo: inverseInfo];
				}
			}
			
			[infos removeObjectIdenticalTo: info];
		}
	}
}

@end
