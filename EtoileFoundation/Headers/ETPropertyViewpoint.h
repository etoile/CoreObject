/**
	<abstract>A viewpoint class to represent an object property.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  December 2007
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETPropertyValueCoding.h>

@class ETUTI;


/** @group Viewpoints

A property viewpoint is an adaptor-like object that represents an object 
property and handles reading and writing the property value through -value and 
-setValue. */
@interface ETPropertyViewpoint : NSObject <ETPropertyValueCoding>
{
	@private
	id _propertyOwner;
	id _propertyName;
	BOOL _treatsAllKeysAsProperties;
	BOOL _usesKVC;
}

/** @taskunit Initialization */

+ (id) viewpointWithName: (NSString *)key representedObject: (id)object;

- (id) initWithName: (NSString *)key representedObject: (id)object;

/** @taskunit Represented Property */

- (NSString *) name;
- (ETUTI *) type;

/** @taskunit Controlling Represented Object Access */

- (id) representedObject;
- (void) setRepresentedObject: (id)object;
- (BOOL) treatsAllKeysAsProperties;
- (void) setTreatsAllKeysAsProperties: (BOOL)exposeAllKeys;

/** @taskunit Reading and Writing the value */

- (id) value;
- (void) setValue: (id)objectValue;

/** @taskunit Property Value Coding */

- (NSArray *) propertyNames;
- (id) valueForProperty: (NSString *)key;
- (BOOL) setValue: (id)value forProperty: (NSString *)key;

@end
