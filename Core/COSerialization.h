/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COType.h>

@class COItem;

extern NSString *kCOObjectEntityNameProperty;

@interface COObject (COSerialization)

@property (nonatomic, copy) COItem *storeItem;

/** @taskunit Serialization */

- (id)serializedValueForValue: (id)aValue;
- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value;

/** @taskunit Deserialization */

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc;
@end
