/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COCoreObjectProtocol.h"
#import "COPropertyType.h"
#import "COUtility.h"
#import <CoreObject/NSObject+CoreObject.h>

@class COObjectContext;

extern NSString *kCOUIDProperty; // kCOStringProperty
extern NSString *kCOVersionProperty; // kCOIntegerProperty
extern NSString *kCOCreationDateProperty; // kCODateProperty
extern NSString *kCOModificationDateProperty; // kCODateProperty
extern NSString *kCOReadOnlyProperty; //kCOIntegerProperty
extern NSString *kCOParentsProperty; // kCOArrayProperty

extern NSString *kCOObjectChangedNotification;
extern NSString *kCOUpdatedProperty;
extern NSString *kCORemovedProperty;

/* Only for search. No real property */
extern NSString *qCOTextContent;

/* For property list */
extern NSString *pCOClassKey;
extern NSString *pCOPropertiesKey;
extern NSString *pCOValuesKey;
extern NSString *pCOVersionKey;
extern NSString *pCOVersion1Value;

@interface COObject: NSObject <COObject, COManagedObject>
{
	/** Persistent properties (except kCOParentsProperty) */
	NSMutableDictionary *_properties;

	/* Transient ivars */

	/** Cache, 
	   Not sure it really makes a difference, ask Yen-Ju... If it does, 
	   probably better to use a global var. */
	NSNotificationCenter *_nc;
	COObjectContext *_objectContext;
	/** The current version of the object. */
	int _objectVersion;
	/** Indicates whether managed method calls are handed to the object context 
	    (see -[COObjectContext recordInvocation:]) */
	BOOL _isPersistencyEnabled;
}

/* Data Model Declaration */

+ (void) initialize;
+ (int) addPropertiesAndTypes: (NSDictionary *) properties;
+ (NSDictionary *) propertiesAndTypes;
+ (NSArray *) properties;
+ (int) removeProperties: (NSArray *) properties;
+ (COPropertyType) typeOfProperty: (NSString *) property;

/* Factory method */

+ (id) objectWithPropertyList: (NSDictionary *) propertyList;

/* Property List Import/Export */

- (id) initWithPropertyList: (NSDictionary *) propertyList;
- (NSMutableDictionary *) propertyList;

/* Common Methods */

- (id) init;
//- (id) initWithURL: (NSURL *)serializationURL 
//   inObjectContext: (COObjectContext *)context;
- (BOOL) tryStartPersistencyIfInstanceOfClass: (Class)aClass;
- (BOOL) isCoreObject;
- (BOOL) isManagedCoreObject;
- (NSDictionary *) metadatas;

/* Managed Object Edition */

- (NSArray *) properties;
- (BOOL) removeValueForProperty: (NSString *) property;
- (BOOL) setValue: (id) value forProperty: (NSString *) property;
- (id) valueForProperty: (NSString *) property;

- (NSArray *) parentGroups; /* Include parents of parents */

- (BOOL) isReadOnly; /* Use KCOReadOnlyProperty to set read-only */
- (int) version;

/* Persistency */

//+ (BOOL) automaticallyWakeUpLibraryAndInsertIntoObjectContext;
//+ (void) setAutomaticallyWakeUpLibraryAndInsertIntoObjectContext: (BOOL)flag;
//- (COLibrary *) library;

- (NSArray *) persistencyMethodNames;
+ (BOOL) automaticallyMakeNewInstancesPersistent;
+ (void) setAutomaticallyMakeNewInstancesPersistent: (BOOL)flag;
- (void) disablePersistency;
- (void) enablePersistency;

- (COObjectContext *) objectContext;
- (BOOL) isPersistent;
- (int) objectVersion;
- (int) lastObjectVersion;
- (BOOL) save;

/* Identity */

- (ETUUID *) UUID;
- (BOOL) isEqual: (id)other;
- (BOOL) isTemporalInstance: (id)other;

/* Query */

- (BOOL) matchesPredicate: (NSPredicate *)aPredicate;

/* Serialization (EtoileSerialize callbacks) */

- (BOOL) serialize: (char *)aVariable using: (ETSerializer *)aSerializer;
- (void *) deserialize: (char *)aVariable 
           fromPointer: (void *)aBlob 
               version: (int)aVersion;
- (void) finishedDeserializing;

/* Deprecated (DO NOT USE, MAY BE REMOVED LATER) */

- (NSString *) uniqueID;

@end
