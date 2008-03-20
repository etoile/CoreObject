/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "COPropertyType.h"

/* CoreObject Protocol (Objects) */

@protocol COObject
/** Adds object to the receiver. */
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
@end

extern NSString *kCOUIDProperty; // kCOStringProperty
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

@interface COObject: NSObject <NSCopying>
{
	NSMutableDictionary *_properties;
	NSNotificationCenter *_nc;
}

+ (int) addPropertiesAndTypes: (NSDictionary *) properties;
+ (NSDictionary *) propertiesAndTypes;
+ (NSArray *) properties;
+ (int) removeProperties: (NSArray *) properties;
+ (COPropertyType) typeOfProperty: (NSString *) property;

+ (id) objectWithPropertyList: (NSDictionary *) propertyList;

- (id) initWithPropertyList: (NSDictionary *) propertyList;
- (NSMutableDictionary *) propertyList;

- (BOOL) removeValueForProperty: (NSString *) property;
- (BOOL) setValue: (id) value forProperty: (NSString *) property;
- (id) valueForProperty: (NSString *) property;

- (NSArray *) parentGroups; /* Include parents of parents */

/* Use KCOReadOnlyProperty to set read-only */
- (BOOL) isReadOnly;

/* Use kCOUIDProperty to set UID */
- (NSString *) uniqueID;

- (BOOL) matchesPredicate: (NSPredicate *) predicate;

@end
