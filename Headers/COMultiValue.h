/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "COPropertyType.h"

/* Unlike ABMultiValue, COMultiValue is always mutable.
   The reason is that unmutable COMultiValue is not very useful. */

@interface COMultiValue: NSObject <NSCopying>
{
	/* We use mutable array of mutable dictionary.
	 * We use mutable collections to make things easier.
	 * This is a performance and memory consumption issue.
	 */
	NSMutableArray *_values;
	NSString *_primaryIdentifier;
	COPropertyType _propertyType;
}

/* For read and write */
- (id) initWithPropertyList: (NSDictionary *) propertyList;
- (NSMutableDictionary *) propertyList;

/* If it is not set, use the first identifier */
- (NSString *) primaryIdentifier;

- (NSString *) identifierAtIndex: (int) index;
- (int) indexForIdentifier: (NSString *) identifier;

- (NSString *) labelAtIndex: (int) index;
- (id) valueAtIndex: (int) index;

- (unsigned int) count;
/* Always use the first type of value. If there is no value, return ErrorType */
- (COPropertyType) propertyType;

/* Mutable */

- (NSString *) addValue: (id) value withLabel: (NSString *) label;
- (NSString *) insertValue: (id) value withLabel: (NSString *) label atIndex: (int) index;

- (BOOL) replaceLabelAtIndex: (int) index withLabel: (NSString *) label;
- (BOOL) replaceValueAtIndex: (int) index withValue: (id) value;

- (BOOL) removeValueAndLabelAtIndex: (int) index;

- (BOOL) setPrimaryIdentifier: (NSString *) identifier;

@end
