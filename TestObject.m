/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "OKObject.h"
#import "OKMultiValue.h"
#import "GNUstep.h"

/* For testing subclass */
@interface SubObject: OKObject
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
	OKMultiValue *mv = [[OKMultiValue alloc] init];
	[mv addValue: @"Value1" withLabel: @"Label1"];
	[mv addValue: @"Value2" withLabel: @"Label2"];
	[mv addValue: @"Value3" withLabel: @"Label3"];
	UKTrue([so setValue: mv forProperty: @"MultiStrings"]);
	DESTROY(mv);
	mv = [[OKMultiValue alloc] init];
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
	/* We don't need multable option here. OKMultiValue should handle it. */
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
	id object = [OKObject objectWithPropertyList: pl];
	UKTrue([object isKindOfClass: [SubObject class]]);
	UKIntsEqual([[object class] typeOfProperty: @"MultiStrings"], kOKMultiStringProperty);
	UKIntsEqual([[object class] typeOfProperty: @"MultiIntegers"], kOKMultiIntegerProperty);
	mv = [object valueForProperty: @"MultiStrings"];
	UKStringsEqual(@"Value1", [mv valueAtIndex: 0]);
	[mv replaceValueAtIndex: 0 withValue: @"NewValue1"];
	UKStringsEqual(@"NewValue1", [mv valueAtIndex: 0]);
}

- (void) testPropertyList
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Contant",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		[NSNumber numberWithInt: kOKMultiStringProperty], 
			@"Multiple",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKObject *o = [[OKObject alloc] init];
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: @"Someone" forProperty: @"Contant"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);
	OKMultiValue *mv = [[OKMultiValue alloc] init];
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

	/* We don't need multable option here. OKMultiValue should handle it. */
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

	OKObject *o1 = [[OKObject alloc] initWithPropertyList: pl];
	UKTrue([o isEqual: o1]); /* Based on uid */
	UKStringsEqual([o valueForProperty: @"Location"],
	               [o1 valueForProperty: @"Location"]);
	UKObjectsEqual([o valueForProperty: @"Float"],
	               [o1 valueForProperty: @"Float"]);
	UKTrue([o setValue: @"Office" forProperty: @"Location"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 3.12] 
	          forProperty: @"Float"]);
	UKStringsNotEqual([o valueForProperty: @"Location"],
	                  [o1 valueForProperty: @"Location"]);
	UKObjectsNotEqual([o valueForProperty: @"Float"],
	                  [o1 valueForProperty: @"Float"]);

	OKObject *o2 = [OKObject objectWithPropertyList: pl];
	UKTrue([o2 isKindOfClass: [OKObject class]]);
}

- (void) testSearchText
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Contant",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		[NSNumber numberWithInt: kOKMultiStringProperty], 
			@"Multiple",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKObject *o = [[OKObject alloc] init];
	UKTrue([o setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o setValue: @"Someone" forProperty: @"Contant"]);
	UKTrue([o setValue: [NSNumber numberWithFloat: 2.12] 
	          forProperty: @"Float"]);
	OKMultiValue *mv = [[OKMultiValue alloc] init];
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
	p1 = [NSPredicate predicateWithFormat: @"%K CONTAINS %@", qOKTextContent, @"Value1"];
	UKTrue([o matchesPredicate: p1]);
	p1 = [NSPredicate predicateWithFormat: @"%K CONTAINS %@", qOKTextContent, @"Someone"];
	UKTrue([o matchesPredicate: p1]);
	
}

- (void) testSearch
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKObject *o = [[OKObject alloc] init];
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
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKObject *o = [[OKObject alloc] init];
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
	OKPropertyType type;
	NSArray *properties = [OKObject properties];
	UKNotNil(properties);
	int count = [properties count];
	type = [OKObject typeOfProperty: kOKUIDProperty];
	UKIntsEqual(type, kOKStringProperty);
	type = [OKObject typeOfProperty: kOKCreationDateProperty];
	UKIntsEqual(type, kOKDateProperty);
	type = [OKObject typeOfProperty: kOKModificationDateProperty];
	UKIntsEqual(type, kOKDateProperty);
	type = [OKObject typeOfProperty: kOKReadOnlyProperty];
	UKIntsEqual(type, kOKIntegerProperty);

	int result = [OKObject removeProperties: [NSArray arrayWithObjects: @"NotExistingProperty", kOKCreationDateProperty, kOKModificationDateProperty, nil]];
	UKIntsEqual(result, 2);
	UKIntsEqual(count-2, [[OKObject properties] count]);

	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKDateProperty], 
			kOKCreationDateProperty,
		[NSNumber numberWithInt: kOKDateProperty], 
			kOKModificationDateProperty,
		nil];
	[OKObject addPropertiesAndTypes: dict];
	UKIntsEqual(count, [[OKObject properties] count]);
	type = [OKObject typeOfProperty: kOKCreationDateProperty];
	UKIntsEqual(type, kOKDateProperty);
}
@end

@implementation SubObject
+ (void) initialize
{       
    NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt: kOKStringProperty],
            kOKUIDProperty,
        [NSNumber numberWithInt: kOKDateProperty],
            kOKCreationDateProperty,
        [NSNumber numberWithInt: kOKDateProperty],
            kOKModificationDateProperty, 
        [NSNumber numberWithInt: kOKIntegerProperty],
            kOKReadOnlyProperty,
        [NSNumber numberWithInt: kOKArrayProperty],
            kOKParentsProperty,
        [NSNumber numberWithInt: kOKMultiStringProperty],
            @"MultiStrings",
        [NSNumber numberWithInt: kOKMultiIntegerProperty],
            @"MultiIntegers",
        nil];
    [SubObject addPropertiesAndTypes: pt];
    DESTROY(pt);
}
@end
