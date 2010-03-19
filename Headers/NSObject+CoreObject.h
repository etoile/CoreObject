/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COObjectContext;

/** All classes whose instances can be managed by CoreObject must conform to 
	this protocol. An object becomes a managed core object when it gets 
	referenced by an UUID in the metadata server and CoreObject oversees its 
	persistency.
	CoreObject provides two classes that adopt this protocol COProxy and 
	COObject related subclasses.*/
@protocol COManagedObject
	
/** Returns the UUID that is used to uniquely identified the receiver as a core 
    object. */
- (ETUUID *) UUID;

/** Returns a hash based on the UUID. */
- (NSUInteger) hash;

/** Returns the current version of the instance. This version represents a 
    revision in the object history. 
    If the object hasn't yet been made persistent, returns -1.
    The returned value is otherwise comprised between 0 (base version created on 
    first serialization) and the last object version. */
- (int) objectVersion;

/** Returns the object context that manages the persistency of the receiver. */
- (COObjectContext *) objectContext;

/** Returns whether other is equal to the receiver.
    Two managed core objects are equal if they share the same UUID and object 
    version. 
    See also -isTemporalInstance:. */
- (BOOL) isEqual: (id)other;

/** Returns whether other is a temporal instance of the receiver.
    Two objects are temporal instances of each other if they share the same 
    UUID but differs by their object version. */
- (BOOL) isTemporalInstance: (id)other;

// TODO: We need to discuss the terminology here and differentiate between 
// metadatas (or persistent properties) and metadatas to be indexed (or 
// indexable persistent properties).
/** Returns the persistent metadatas to be indexed. */
- (NSDictionary *) metadatas;
@end

/* NSObject extensions */

@interface NSObject (CoreObject)

- (BOOL) isCoreObject;
- (BOOL) isManagedCoreObject;
- (BOOL) isCoreObjectProxy;
- (BOOL) isFault;

@end

@interface ETUUID (CoreObject)
- (BOOL) isFault;
@end
