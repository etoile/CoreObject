/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  August 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

#import <CoreObject/CoreObject.h>

@interface COCrossPersistentRootReferenceCache : NSObject
{
    NSMapTable *_weakObjectToCrossRefInfoArray;
    NSMutableDictionary *_persistentRootUUIDToCrossRefInfoArray;
}

- (NSArray *) referencedPersistentRootUUIDsForObject: (COObject *)anObject;
- (NSArray *) affectedObjectsForChangeInPersistentRoot: (ETUUID *)aPersistentRoot;

- (void) clearReferencedPersistentRootsForProperty: (NSString *)aProperty
										  ofObject: (COObject *)anObject;
- (void) addReferencedPersistentRoot: (ETUUID *)aPersistentRoot
						 forProperty: (NSString *)aProperty
							ofObject: (COObject *)anObject;

@end
