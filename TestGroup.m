/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "OKGroup.h"
#import "GNUstep.h"

@interface TestGroup: NSObject <UKTest>
@end

@implementation TestGroup
- (id) init
{
	self = [super init];
	return self;
}

- (void) dealloc
{
	[super dealloc];
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

	OKGroup *g = [[OKGroup alloc] init];
	OKObject *o1= [[OKObject alloc] init];
	[o1 setValue: @"Home" forProperty: @"Location"];
	[o1 setValue: [NSNumber numberWithFloat: 2.12] forProperty: @"Float"];
	UKTrue([g addObject: o1]);

	OKObject *o2 = [[OKObject alloc] init];
	[o2 setValue: @"Office" forProperty: @"Location"];
	[o2 setValue: [NSNumber numberWithFloat: 11.2] forProperty: @"Float"];
	UKTrue([g addObject: o2]);

	OKObject *o3 = [[OKObject alloc] init];
	[o3 setValue: @"Vacation" forProperty: @"Location"];
	[o3 setValue: [NSNumber numberWithFloat: 0] forProperty: @"Float"];
	UKTrue([g addObject: o3]);

	OKObject *o4 = [[OKObject alloc] init];
	[o4 setValue: @"Factory" forProperty: @"Location"];
	[o4 setValue: [NSNumber numberWithFloat: 20.1] forProperty: @"Float"];
	UKTrue([g addObject: o4]);

	NSArray *array = nil;
	NSPredicate *p1;
	p1 = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Home"];
	array = [g objectsMatchingPredicate: p1];
	UKNotNil(array);
	UKIntsEqual([array count], 1);
	UKObjectsEqual([array objectAtIndex: 0], o1);
#if 0
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
#endif
	DESTROY(o1);
	DESTROY(o2);
	DESTROY(o3);
	DESTROY(o4);
}

- (void) testObjects
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKGroup *g = [[OKGroup alloc] init];
	OKObject *o1= [[OKObject alloc] init];
	[o1 setValue: @"Home" forProperty: @"Location"];
	[o1 setValue: [NSNumber numberWithFloat: 2.12] forProperty: @"Float"];
	UKTrue([g addObject: o1]);

	OKObject *o2 = [[OKObject alloc] init];
	[o2 setValue: @"Office" forProperty: @"Location"];
	[o2 setValue: [NSNumber numberWithFloat: 11.2] forProperty: @"Float"];
	UKTrue([g addObject: o2]);

	OKObject *o3 = [[OKObject alloc] init];
	[o3 setValue: @"Vacation" forProperty: @"Location"];
	[o3 setValue: [NSNumber numberWithFloat: 0] forProperty: @"Float"];
	UKTrue([g addObject: o3]);

	OKObject *o4 = [[OKObject alloc] init];
	[o4 setValue: @"Factory" forProperty: @"Location"];
	[o4 setValue: [NSNumber numberWithFloat: 20.1] forProperty: @"Float"];
	UKTrue([g addObject: o4]);

	NSArray *a = [g objects];
	UKIntsEqual([a count], 4);
	NSArray *p = [o1 parentGroups];
	UKTrue([p containsObject: g]);
	UKTrue([g removeObject: o3]);
	UKIntsEqual([a count], 3);
	p = [o3 parentGroups];
	UKIntsEqual([p count], 0);

	DESTROY(o1);
	DESTROY(o2);
	DESTROY(o3);
	DESTROY(o4);
}

- (void) testPropertyList
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKGroup *g = [[OKGroup alloc] init];
	OKObject *o1= [[OKObject alloc] init];
	[o1 setValue: @"Home" forProperty: @"Location"];
	[o1 setValue: [NSNumber numberWithFloat: 2.12] forProperty: @"Float"];
	UKTrue([g addObject: o1]);
	UKIntsEqual([[g objects] count], 1);

	/* We test property list here */
	id pl = [g propertyList];
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

	OKGroup *group = [OKGroup objectWithPropertyList: pl];
	UKTrue([group isKindOfClass: [OKGroup class]]);
	UKIntsEqual([[group objects] count], 1);
	UKIntsEqual([[group allGroups] count], 0);
	UKIntsEqual([[group allObjects] count], 1);
}

- (void) testGroup
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKGroup *g = [[OKGroup alloc] init];
	OKObject *o1= [[OKObject alloc] init];
	[o1 setValue: @"Home" forProperty: @"Location"];
	[o1 setValue: [NSNumber numberWithFloat: 2.12] forProperty: @"Float"];
	UKTrue([g addObject: o1]);
	UKIntsEqual([[g objects] count], 1);

	OKObject *o2 = [[OKObject alloc] init];
	[o2 setValue: @"Office" forProperty: @"Location"];
	[o2 setValue: [NSNumber numberWithFloat: 11.2] forProperty: @"Float"];
	UKTrue([g addObject: o2]);
	UKIntsEqual([[g objects] count], 2);

	OKObject *o3 = [[OKObject alloc] init];
	[o3 setValue: @"Vacation" forProperty: @"Location"];
	[o3 setValue: [NSNumber numberWithFloat: 0] forProperty: @"Float"];
	UKTrue([g addObject: o3]);
	UKIntsEqual([[g objects] count], 3);

	OKObject *o4 = [[OKObject alloc] init];
	[o4 setValue: @"Factory" forProperty: @"Location"];
	[o4 setValue: [NSNumber numberWithFloat: 20.1] forProperty: @"Float"];
	UKTrue([g addObject: o4]);
	UKIntsEqual([[g objects] count], 4);

	OKGroup *g1 = [[OKGroup alloc] init];
	[g1 addObject: o1];
	[g1 addObject: o2];
	[g1 addObject: o3];
	UKTrue([g addSubgroup: g1]);
	UKIntsEqual([[g subgroups] count], 1);
	UKIntsEqual([[g1 objects] count], 3);

	OKGroup *g2 = [[OKGroup alloc] init];
	[g2 addObject: o1];
	[g2 addObject: o4];
	UKTrue([g addSubgroup: g2]);
	UKIntsEqual([[g subgroups] count], 2);
	UKIntsEqual([[g2 objects] count], 2);

	OKGroup *g3 = [[OKGroup alloc] init];
	UKTrue([g addSubgroup: g3]);
	UKIntsEqual([[g subgroups] count], 3);
	UKIntsEqual([[g3 objects] count], 0);

	OKGroup *gg1 = [[OKGroup alloc] init];
	UKTrue([g1 addSubgroup: gg1]);
	UKIntsEqual([[g1 objects] count], 3);
	UKIntsEqual([[g1 subgroups] count], 1);

	UKIntsEqual([[g objects] count], 4);
	UKIntsEqual([[g allObjects] count], 4);
	UKIntsEqual([[g subgroups] count], 3);
	UKIntsEqual([[g allGroups] count], 4);

	/* We test property list here */
	id pl = [g propertyList];
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
	NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent: @"TextGroup.plist"];
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
	OKGroup *group = [OKGroup objectWithPropertyList: pl];
	UKTrue([group isKindOfClass: [OKGroup class]]);
	UKIntsEqual([[group objects] count], 4);
	UKIntsEqual([[group allObjects] count], 4);
	UKIntsEqual([[group subgroups] count], 3);
	UKIntsEqual([[group allGroups] count], 4);
}

- (void) testProperties
{
	/* Let's make sure OKGroup inherit from OKObject */
	UKIntsEqual(kOKStringProperty, [OKGroup typeOfProperty: kOKUIDProperty]);
	UKIntsEqual(kOKIntegerProperty, [OKGroup typeOfProperty: kOKReadOnlyProperty]);
	/* And our own property */
	UKIntsEqual(kOKArrayProperty, [OKGroup typeOfProperty: kOKGroupChildrenProperty]);
}

@end
