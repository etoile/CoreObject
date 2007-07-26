/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "OKPropertyType.h"

extern NSString *kOKUIDProperty; // kOKStringProperty
extern NSString *kOKCreationDateProperty; // kOKDateProperty
extern NSString *kOKModificationDateProperty; // kOKDateProperty
extern NSString *kOKReadOnlyProperty; //kOKIntegerProperty
extern NSString *kOKParentsProperty; // kOKArrayProperty
extern NSString *kOKTagProperty; // kOKArrayProperty

extern NSString *kOKObjectChangedNotification;
extern NSString *kOKUpdatedProperty;
extern NSString *kOKRemovedProperty;

/* Only for search. No real property */
extern NSString *qOKTextContent;

/* For property list */
extern NSString *pOKClassKey;
extern NSString *pOKPropertiesKey;
extern NSString *pOKValuesKey;
extern NSString *pOKVersionKey;
extern NSString *pOKVersion1Value;

@interface OKObject: NSObject <NSCopying>
{
	NSMutableDictionary *_properties;
	NSNotificationCenter *_nc;
}

+ (int) addPropertiesAndTypes: (NSDictionary *) properties;
+ (NSDictionary *) propertiesAndTypes;
+ (NSArray *) properties;
+ (int) removeProperties: (NSArray *) properties;
+ (OKPropertyType) typeOfProperty: (NSString *) property;

+ (id) objectWithPropertyList: (NSDictionary *) propertyList;

- (id) initWithPropertyList: (NSDictionary *) propertyList;
- (NSMutableDictionary *) propertyList;

- (BOOL) removeValueForProperty: (NSString *) property;
- (BOOL) setValue: (id) value forProperty: (NSString *) property;
- (id) valueForProperty: (NSString *) property;

- (NSArray *) parentGroups; /* Include parents of parents */

/* Use KOKReadOnlyProperty to set read-only */
- (BOOL) isReadOnly;

/* Use kOKUIDProperty to set UID */
- (NSString *) uniqueID;

- (BOOL) matchesPredicate: (NSPredicate *) predicate;

@end
