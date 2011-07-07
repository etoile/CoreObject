/*
   Copyright (C) 2009 Quentin Mathe <qmathe gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COEditingContext, COObject;

/** The protocol to which any fault class must comply to. 

CoreObject comes with two concrete fault classes COObjectFault and COProxy. 

Specialized fault classes can be implemented, but this should never be needed.

Any concrete fault class to be associated to a particular core object class 
has to be returned  by overriding or implementing the +faultClass method. */
@protocol COFault <NSObject>
/** Deserializes the real object and enables its persistency.

When the real object is already loaded, must return nil immediately.

When the loading succeeds, must return nil, otherwise must return an error 
that explains the failure.

Once the method returns, -isFault must return YES on success and the receiver 
should be ready to receive any message including those which are 
persistency-related. */
- (NSError *) unfaultIfNeeded;

/** @taskunit Identity */

/** See -[NSObject isFault]. */
- (BOOL) isFault;
/** See -[COObject hash]. */
- (unsigned int) hash;
/** See -[COObject UUID]. */
- (ETUUID *) UUID;
/** See -[COObject editingContext]. */
- (COEditingContext *) editingContext;
/** See -[COObject isEqual:]. */
- (BOOL) isEqual: (id)other;

@end


/** The basic CoreObject fault class used by the COObject class hierarchy. */
@interface COObjectFault : NSProxy <COFault>
{
	@private
	ETEntityDescription *_entityDescription;
	ETUUID *_uuid;
	COEditingContext *_context; // weak reference
	COObject *_rootObject; // weak reference
	NSMapTable *_variableStorage;
	BOOL _isIgnoringDamageNotifications;
}

@end

