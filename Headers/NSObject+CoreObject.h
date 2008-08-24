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
	referenced by an UUID in the metadata server.
	CoreObject provides two classes that adopt this protocol COProxy and 
	COObject related subclasses.*/
@protocol COManagedObject
/** This initializer is only useful when you create a managed object for the first time
	aContext may be nil if you want manage the object by yourself (usually when 
	you managed a single model object at a time, for example in a document in a 
	document editor). In a document editor, each document has its own history 
	and undo stack unlike in an object manager where the history/evolution of 
	all model/managed objects are interleaved.
	In a document editor, the active persistency history depends of the active 
	model objects. An active model object is usually a document in this case, but 
	can also be an inspector or the object that manages the preferences (user 
	defaults). But even in this case, using an object context can be useful to allow 
	the user to revert inspector-specific changes when the inspector has lost the 
	focus. May not make sense at UI level. */
//- (id) initWithLibrary: (id)aLibrary inObjectContext: (COObjectContext *)aContext;
//- (id) initWithUUID: (ETUUID *)anUUID inObjectContext: (COObjectContext *)aContext;
//- (id) initWithURL: (NSURL *)anURL inObjectContext: (COObjectContext *)aContext;
- (ETUUID *) UUID;
//- (id) localStore;
// TODO: We need to discuss the terminology here and differentiate between 
// metadatas (or persistent properties) and metadatas to be indexed (or 
// indexable persistent properties). 
//- (NSDictionary *) metadatas;
//- (int) version;
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
