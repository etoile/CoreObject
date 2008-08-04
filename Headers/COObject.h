/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COPropertyType.h"
#import "COUtility.h"

@class COObjectContext;

/* CoreObject Protocol (Objects) */

@protocol COObject <NSObject, NSCopying>
- (BOOL) isCopyPromise;
/** Returns the model properties of the receiver. 
	Properties should encompass all model attributes and relationships that you 
	want to publish. Your Property-Value Coding implementation will determine
	for each one whether they are readable, writable or both.*/
- (NSArray *) properties;
/** Returns the metadatas of the receiver to be indexed by the metadata server. 
	The set of metadatas may intersect or not the set of properties. */
- (NSDictionary *) metadatas;
//- (NSArray *) parentGroups;
/** Returns a unique ID that can be used to recreate a previously known object 
	by passing this value to -initWithUniqueID:.
	The choice of the unique ID scheme is up to the class that conforms to 
	COObject protocol. 
	A common choice is to return the absolute string form of the URL that 
	identifies the receiver object. 
	The FS backend  (COFile and CODirectory) uses a combination of the related 
	filesystem inode and device/volume identifier.
	The Native backend (COObject and COGroup) uses an UUID. */
- (NSString *) uniqueID;
//- (id) initWithUniqueID:
@end

extern NSString *kCOUIDProperty; // kCOStringProperty
extern NSString *kCOVersionProperty; // kCOIntegerProperty
extern NSString *kCOCreationDateProperty; // kCODateProperty
extern NSString *kCOModificationDateProperty; // kCODateProperty
extern NSString *kCOReadOnlyProperty; //kCOIntegerProperty
extern NSString *kCOParentsProperty; // kCOArrayProperty
extern NSString *kCOTagProperty; // kCOArrayProperty

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

@interface COObject: NSObject <COObject>
{
	NSMutableDictionary *_properties;
	NSNotificationCenter *_nc;
	COObjectContext *_objectContext;
	/** The current version of the object. */
	int _objectVersion;
}

/* Data Model Declaration */

+ (int) addPropertiesAndTypes: (NSDictionary *) properties;
+ (NSDictionary *) propertiesAndTypes;
+ (NSArray *) properties;
+ (int) removeProperties: (NSArray *) properties;
+ (COPropertyType) typeOfProperty: (NSString *) property;

+ (id) objectWithPropertyList: (NSDictionary *) propertyList;

/* Property List Import/Export */

- (id) initWithPropertyList: (NSDictionary *) propertyList;
- (NSMutableDictionary *) propertyList;

/* Managed Object Edition */

- (NSArray *) properties;
- (BOOL) removeValueForProperty: (NSString *) property;
- (BOOL) setValue: (id) value forProperty: (NSString *) property;
- (id) valueForProperty: (NSString *) property;

- (NSArray *) parentGroups; /* Include parents of parents */

- (BOOL) isReadOnly; /* Use KCOReadOnlyProperty to set read-only */

/* Persistency */

+ (BOOL) automaticallyMakeNewInstancesPersistent;
+ (void) setAutomaticallyMakeNewInstancesPersistent: (BOOL)flag;

- (int) version; /* Use kCOUIDProperty to set UID */

- (COObjectContext *) objectContext;
- (BOOL) isPersistent;
- (int) objectVersion;
- (int) lastObjectVersion;
- (BOOL) save;
- (ETUUID *) UUID;

/* Query */

- (BOOL) matchesPredicate: (NSPredicate *) predicate;

/* Private (Object Versioning callbacks) */

- (void) deserializerDidFinish: (ETDeserializer *)deserializer forVersion: (int)objectVersion;
- (void) serializerDidFinish: (ETSerializer *)serializer forVersion: (int)objectVersion;

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (NSString *) uniqueID;

@end
