/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COObject.h"
#import "COMultiValue.h"
#import "GNUstep.h"

/* For testing subclass */
@interface SubObject: COObject
@end

@interface TestObject: NSObject <UKTest>
@end

@implementation TestObject
- (id) init
{
	self = [super init];
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

- (void) testSubclass
{
	SubObject *so = [[SubObject alloc] init];
	COMultiValue *mv = [[COMultiValue alloc] init];
	[mv addValue: @"Value1" withLabel: @"Label1"];
	[mv addValue: @"Value2" withLabel: @"Label2"];
	[mv addValue: @"Value3" withLabel: @"Label3"];
	UKTrue([so setValue: mv forProperty: @"MultiStrings"]);
	DESTROY(mv);
	mv = [[COMultiValue alloc] init];
	[mv addValue: [NSNumber numberWithInt: 1] withLabel: @"I1"];
	[mv addValue: [NSNumber numberWithInt: 2] withLabel: @"I2"];
	[mv addValue: [NSNumber numberWithInt: 3] withLabel: @"I3"];
	UKTrue([so setValue: mv forProperty: @"MultiIntegers"]);
	DESTROY(mv);

	id pl = [so propertyList];
	/* Make sure we can save it */
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: pl
	                                format: NSPropertyListXMLFormat_v1_0
	                                            errorDescription: &error];
	UKNotNil(data);
	if (data == nil)
	{
		NSLog(@"Error: %@ (%@ %@)", error, self, NSStringFromSelector(_cmd));
	}
	/* We don't need multable option here. COMultiValue should handle it. */
	error = nil;
	NSPropertyListFormat format = 0;
    pl = [NSPropertyListSerialization propertyListFromData: data
	                                  mutabilityOption: NSPropertyListImmutable
	                                  format: &format
	                                  errorDescription: &error];
	UKNotNil(pl);
	UKIntsEqual(format, NSPropertyListXMLFormat_v1_0);
	if (pl == nil)
	{
		NSLog(@"Error: %@ (%@ %@)", error, self, NSStringFromSelector(_cmd));
	}
	id object = [COObject objectWithPropertyList: pl];
	UKTrue([object isKindOfClass: [SubObject class]]);
	UKIntsEqual([[object class] typeOfProperty: @"MultiStrings"], kCOMultiStringProperty);
	UKIntsEqual([[object class] typeOfProperty: @"MultiIntegers"], kCOMultiIntegerProperty);
	mv = [object valueForProperty: @"MultiStrings"];
	UKStringsEqual(@"Value1", [mv valueAtIndex: 0]);
	[mv replaceValueAtIndex: 0 withValue: @"NewValue1"];
	UKStringsEqual(@"NewValue1", [mv valueAtIndex: 0]);
}

- (void) testPropertyList
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Contant",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		[NSNumber numberWithInt: kCOMultiStringProperty], 
			@"Multiple",
		nil];
	[COObject addPropertiesAndTypes: dict];

	COObject *o = [[COObject alloc] init];
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: @"Someone" forProperty: @"Contant"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);
	COMultiValue *mv = [[COMultiValue alloc] init];
	[mv addValue: @"Value1" withLabel: @"Label1"];
	[mv addValue: @"Value2" withLabel: @"Label2"];
	[mv addValue: @"Value3" withLabel: @"Label3"];
	UKTrue([o setValue: mv forProperty: @"Multiple"]);
	DESTROY(mv);

	id pl = [o propertyList];
	/* Make sure we can save it */
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: pl
	                                format: NSPropertyListXMLFormat_v1_0
	                                            errorDescription: &error];
	UKNotNil(data);
	if (data == nil)
	{
		NSLog(@"Error: %@ (%@ %@)", error, self, NSStringFromSelector(_cmd));
	}

#if 0
	/* Write to disk for examine */
	NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent: @"TextObject.plist"];
	[data writeToFile: p atomically: YES];
	NSLog(@"Write to file %@", p);
#endif

	/* We don't need multable option here. COMultiValue should handle it. */
	error = nil;
	NSPropertyListFormat format = 0;
    pl = [NSPropertyListSerialization propertyListFromData: data
	                                  mutabilityOption: NSPropertyListImmutable
	                                  format: &format
	                                  errorDescription: &error];
	UKNotNil(pl);
	UKIntsEqual(format, NSPropertyListXMLFormat_v1_0);
	if (pl == nil)
	{
		NSLog(@"Error: %@ (%@ %@)", error, self, NSStringFromSelector(_cmd));
	}

	COObject *o1 = [[COObject alloc] initWithPropertyList: pl];
	UKTrue([o isEqual: o1]); /* Based on uid */
	UKStringsEqual([o valueForProperty: @"Location"],
	               [o1 valueForProperty: @"Location"]);
#ifdef GNUSTEP
	UKTrue([[o valueForProperty: @"Float"] floatValue] ==
	               [[o1 valueForProperty: @"Float"] floatValue]);
#else
	// FIXME: This test fails on GNUstep, as if -[NSValue isEqual:] was buggy.
	UKObjectsEqual([o valueForProperty: @"Float"],
	               [o1 valueForProperty: @"Float"]);
#endif
	UKTrue([o setValue: @"Office" forProperty: @"Location"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 3.12] 
	          forProperty: @"Float"]);
	UKStringsNotEqual([o valueForProperty: @"Location"],
	                  [o1 valueForProperty: @"Location"]);
	UKObjectsNotEqual([o valueForProperty: @"Float"],
	                  [o1 valueForProperty: @"Float"]);

	COObject *o2 = [COObject objectWithPropertyList: pl];
	UKTrue([o2 isKindOfClass: [COObject class]]);
}

- (void) testSearchText
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Contant",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		[NSNumber numberWithInt: kCOMultiStringProperty], 
			@"Multiple",
		nil];
	[COObject addPropertiesAndTypes: dict];

	COObject *o = [[COObject alloc] init];
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: @"Someone" forProperty: @"Contant"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);
	COMultiValue *mv = [[COMultiValue alloc] init];
	[mv addValue: @"Value1" withLabel: @"Label1"];
	[mv addValue: @"Value2" withLabel: @"Label2"];
	[mv addValue: @"Value3" withLabel: @"Label3"];
	UKTrue([o setValue: mv forProperty: @"Multiple"]);
	DESTROY(mv);

	NSPredicate *p1;
	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Home"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K CONTAINS %@", @"Location", @"om"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Multiple.Label1", @"Value1"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K CONTAINS %@", qCOTextContent, @"Value1"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K CONTAINS %@", qCOTextContent, @"Someone"];
	UKTrue([o matchesPredicate: p1]);
	
}

- (void) testSearch
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		nil];
	[COObject addPropertiesAndTypes: dict];

	COObject *o = [[COObject alloc] init];
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);

	NSPredicate *p1;
	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Home"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K BEGINSWITH %@", @"Location", @"Ho"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K ENDSWITH %@", @"Location", @"Ho"];
	UKFalse([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K ENDSWITH %@", @"Location", @"me"];
	UKTrue([o matchesPredicate: p1]);

	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Float", [NSNumber numberWithFloat: 2.12]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Float", [NSNumber numberWithFloat: 4.12]];
	UKFalse([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K > %@", @"Float", [NSNumber numberWithFloat: 1.00]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K >= %@", @"Float", [NSNumber numberWithFloat: 1.00]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K >= %@", @"Float", [NSNumber numberWithFloat: 2.12]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K >= %@", @"Float", [NSNumber numberWithFloat: 4.12]];
	UKFalse([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K < %@", @"Float", [NSNumber numberWithFloat: 3.00]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K <= %@", @"Float", [NSNumber numberWithFloat: 4.12]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K <= %@", @"Float", [NSNumber numberWithFloat: 2.12]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K <= %@", @"Float", [NSNumber numberWithFloat: 2.11]];
	UKFalse([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K <= %@", @"Float", [NSNumber numberWithFloat: 2.11]];
	UKFalse([o matchesPredicate: p1]);

	p1 = [NSPredicate predicateWithFormat: @"%K == %@ AND %K < %@", @"Location", @"Home", @"Float", [NSNumber numberWithFloat: 4]];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K == %@ AND (NOT %K < %@)", @"Location", @"Home", @"Float", [NSNumber numberWithFloat: 4]];
	UKFalse([o matchesPredicate: p1]);

	DESTROY(o);
}

- (void) testBasic
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		nil];
	[COObject addPropertiesAndTypes: dict];

	COObject *o = [[COObject alloc] init];
	UKFalse([o isReadOnly]);
	UKNotNil([o uniqueID]);
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);
	UKStringsEqual(@"Home", [o valueForProperty: @"Location"]);
	UKNil([o valueForProperty: @"NotExisting"]);
	UKTrue([o removeValueForProperty: @"Location"]);
	UKNil([o valueForProperty: @"Location"]);
	DESTROY(o);
}

- (void) testPropertiesAndTypes
{
	COPropertyType type;
	NSArray *properties = [COObject properties];
	UKNotNil(properties);
	int count = [properties count];
	type = [COObject typeOfProperty: kCOUIDProperty];
	UKIntsEqual(type, kCOStringProperty);
	type = [COObject typeOfProperty: kCOVersionProperty];
	UKIntsEqual(type, kCOIntegerProperty);
	type = [COObject typeOfProperty: kCOCreationDateProperty];
	UKIntsEqual(type, kCODateProperty);
	type = [COObject typeOfProperty: kCOModificationDateProperty];
	UKIntsEqual(type, kCODateProperty);
	type = [COObject typeOfProperty: kCOReadOnlyProperty];
	UKIntsEqual(type, kCOIntegerProperty);

	int result = [COObject removeProperties: [NSArray arrayWithObjects: @"NotExistingProperty", kCOCreationDateProperty, kCOModificationDateProperty, nil]];
	UKIntsEqual(result, 2);
	UKIntsEqual(count-2, [[COObject properties] count]);

	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCODateProperty], 
			kCOCreationDateProperty,
		[NSNumber numberWithInt: kCODateProperty], 
			kCOModificationDateProperty,
		nil];
	[COObject addPropertiesAndTypes: dict];
	UKIntsEqual(count, [[COObject properties] count]);
	type = [COObject typeOfProperty: kCOCreationDateProperty];
	UKIntsEqual(type, kCODateProperty);
}
@end

@implementation SubObject
+ (void) initialize
{       
    NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kCOStringProperty],
            kCOUIDProperty,
        [NSNumber numberWithInt: kCOIntegerProperty],
            kCOVersionProperty,
        [NSNumber numberWithInt: kCODateProperty],
            kCOCreationDateProperty,
        [NSNumber numberWithInt: kCODateProperty],
            kCOModificationDateProperty, 
        [NSNumber numberWithInt: kCOIntegerProperty],
            kCOReadOnlyProperty,
        [NSNumber numberWithInt: kCOArrayProperty],
            kCOParentsProperty,
        [NSNumber numberWithInt: kCOMultiStringProperty],
            @"MultiStrings",
        [NSNumber numberWithInt: kCOMultiIntegerProperty],
            @"MultiIntegers",
        nil];
    [SubObject addPropertiesAndTypes: pt];
    DESTROY(pt);
}
@end
