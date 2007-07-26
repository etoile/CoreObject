/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import "OKPropertyType.h"

/* Unlike ABMultiValue, OKMultiValue is always mutable.
   The reason is that unmutable OKMultiValue is not very useful. */

@interface OKMultiValue: NSObject <NSCopying>
{
	/* We use mutable array of mutable dictionary.
	 * We use mutable collections to make things easier.
	 * This is a performance and memory consumption issue.
	 */
	NSMutableArray *_values;
	NSString *_primaryIdentifier;
	OKPropertyType _propertyType;
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
- (OKPropertyType) propertyType;

/* Mutable */

- (NSString *) addValue: (id) value withLabel: (NSString *) label;
- (NSString *) insertValue: (id) value withLabel: (NSString *) label atIndex: (int) index;

- (BOOL) replaceLabelAtIndex: (int) index withLabel: (NSString *) label;
- (BOOL) replaceValueAtIndex: (int) index withValue: (id) value;

- (BOOL) removeValueAndLabelAtIndex: (int) index;

- (BOOL) setPrimaryIdentifier: (NSString *) identifier;

@end
