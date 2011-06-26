/**
	<abstract>Property Value Coding protocol used by CoreObject and 
	EtoileUI provides a unified API to implement access, mutation, 
	delegation and late-binding of properties.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  December 2007
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>


/** @group Model and Metamodel

Protocol usually adopted by model objects */
@protocol ETPropertyValueCoding
- (NSArray *) propertyNames;
- (id) valueForProperty: (NSString *)key;
- (BOOL) setValue: (id)value forProperty: (NSString *)key;
@end


/** @group Model and Metamodel */
@interface NSDictionary (ETPropertyValueCoding) <ETPropertyValueCoding>
- (NSArray *) propertyNames;
- (id) valueForProperty: (NSString *)key;
- (BOOL) setValue: (id)value forProperty: (NSString *)key;
@end

/** @group Model and Metamodel */
@interface NSMutableDictionary (ETMutablePropertyValueCoding)
- (BOOL) setValue: (id)value forProperty: (NSString *)key;
@end
