/*
   Copyright (C) 2009 Quentin Mathe <qmathe gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>

/** The protocol to which any fault class must comply to. 

CoreObject comes with two concrete fault classes COBasicFault and COProxy. 

Specialized fault classes can be implemented, but this should never be needed.

Any concrete fault class to be associated to a particular core object class 
has to be returned  by overriding or implementing the +faultClass method. */
@protocol COFault <NSObject>

/** Initializes and returns a new fault object that can later be turned into 
a core object.

aClassName describes the class to set on the core object when -load is invoked. 
It might be another class that the original one. For example, a COGroup or 
COPerson can be instantiated as a COObject. This is mainly useful to let 
arbitrary applications read/write the data model with their own schema and when  
the original class is not available. This also help to minimize the number of 
loaded frameworks/classes when traversing the CoreObject graph in a very open 
way (e.g. as a generic object manager would allow it).

anInstanceSize gives the final size of the core object in memory. This size 
always corresponds to the original class instance size. Hence a COPerson loaded 
as a COObject can later become a true COPerson if the class gets loaded.<br />
The instance size is usually cached in the Metadata DB.

On return, -isFault must return NO. */
- (id) initWithUUID: (ETUUID *)anUUID 
    futureClassName: (NSString *)aClassName
       instanceSize: (NSUInteger)anInstanceSize;
/** Deserializes the real object and enables its persistency.

When the real object is already loaded, must return nil immediately.

When the loading succeeds, must return nil, otherwise must return an error 
that explains the failure.

Once the method returns, -isFault must return YES on success and the receiver 
should be ready to receive any message including those which are 
persistency-related. */
- (NSError *) load;

/* Identity */

/** See -[NSObject isFault]. */
- (BOOL) isFault;
/** See -[(COManagedObject) hash]. */
- (unsigned int) hash;
/** See -[(COManagedObject) UUID]. */
- (ETUUID *) UUID;
/** See -[(COManagedObject) isEqual:]. */
- (BOOL) isEqual: (id)other;

@end


/** Describes what must be known to instantiate a fault for a core object.

You don't have to implement this protocol, but COMetadataServer return objects 
that conforms to it. */
@protocol COFaultDescription
/** Returns the core object class name. */
- (NSString *) objectType;
/** Returns the core object size in memory. */
- (NSUInteger) instanceSize;
@end


/** The basic CoreObject fault class used by the COObject class hierarchy. */
@interface COObjectFault : NSObject <COFault>
{
	@private
	/* Object identity */
	ETUUID *_uuid;
	/* Class to set on the receiver */
	NSString *_futureClassName;
	/* Object managing the receiver persistency */
	COObjectContext *_objectContext;
}

@end

