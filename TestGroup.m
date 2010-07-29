/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COGroup.h"
#import "COObjectServer.h"
#import "COObjectContext.h"
#import "GNUstep.h"

@interface COObjectServer (Test)
+ (void) makeNewDefaultServer;
@end

@interface TestGroup : NSObject <UKTest>
{
	COGroup *g;
	COObject *o1;
	COObject *o2;
	COObject *o3;
	COObject *o4;
	COGroup *g1;
	COGroup *g2;
	COGroup *g3;
	COGroup *gg1;
}

@end

@implementation TestGroup

- (id) initForTest
{
	SUPERINIT

	/* Object server and context are used by -testResolveFaults */
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: AUTORELEASE([[COObjectContext alloc] init])];

	g = [[COGroup alloc] init];
	o1 = [[COObject alloc] init];
	[o1 setValue: @"Home" forProperty: @"Location"];
	[o1 setValue: [NSNumber numberWithFloat: 2.12] forProperty: @"Float"];

	o2 = [[COObject alloc] init];
	[o2 setValue: @"Office" forProperty: @"Location"];
	[o2 setValue: [NSNumber numberWithFloat: 11.2] forProperty: @"Float"];

	o3 = [[COObject alloc] init];
	[o3 setValue: @"Vacation" forProperty: @"Location"];
	[o3 setValue: [NSNumber numberWithFloat: 0] forProperty: @"Float"];

	o4 = [[COObject alloc] init];
	[o4 setValue: @"Factory" forProperty: @"Location"];
	[o4 setValue: [NSNumber numberWithFloat: 20.1] forProperty: @"Float"];
	
	g1 = [[COGroup alloc] init];
	g2 = [[COGroup alloc] init];
	g3 = [[COGroup alloc] init];
	gg1 = [[COGroup alloc] init];
	
	return self;
}

- (void) releaseForTest
{
	DESTROY(o1);
	DESTROY(o2);
	DESTROY(o3);
	DESTROY(o4);
	DESTROY(g1);
	DESTROY(g2);
	DESTROY(g3);
	DESTROY(gg1);

	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: AUTORELEASE([[COObjectContext alloc] init])];

	[super release];
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

	UKTrue([g addMember: o1]);
	UKTrue([g addMember: o2]);
	UKTrue([g addMember: o3]);
	UKTrue([g addMember: o4]);

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
}

- (void) testObjects
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		nil];
	[COObject addPropertiesAndTypes: dict];

	UKTrue([g addMember: o1]);
	UKTrue([g addMember: o2]);
	UKTrue([g addMember: o3]);
	UKTrue([g addMember: o4]);

	NSArray *a = [g members];
	UKIntsEqual([a count], 4);
	NSArray *p = [o1 parentGroups];
	UKTrue([p containsObject: g]);
	UKTrue([g removeMember: o3]);
	
	// Commented out the following test because it assumes [g members] will 
	// continue to update when the group does.  
	//UKIntsEqual([a count], 3);
	p = [o3 parentGroups];
	UKIntsEqual([p count], 0);
}

- (void) testPropertyList
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		nil];
	[COObject addPropertiesAndTypes: dict];

	UKTrue([g addMember: o1]);
	UKIntsEqual([[g members] count], 1);

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

	COGroup *group = [COGroup objectWithPropertyList: pl];
	UKTrue([group isKindOfClass: [COGroup class]]);
	UKIntsEqual([[group members] count], 1);
	UKIntsEqual([[group allGroups] count], 0);
	UKIntsEqual([[group allObjects] count], 1);
}

- (void) testGroup
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kCORealProperty], 
			@"Float",
		nil];
	[COObject addPropertiesAndTypes: dict];

	UKTrue([g addMember: o1]);
	UKIntsEqual([[g members] count], 1);
	UKTrue([g addMember: o2]);
	UKIntsEqual([[g members] count], 2);
	UKTrue([g addMember: o3]);
	UKIntsEqual([[g members] count], 3);
	UKTrue([g addMember: o4]);
	UKIntsEqual([[g members] count], 4);

	[g1 addMember: o1];
	[g1 addMember: o2];
	[g1 addMember: o3];
	UKTrue([g addGroup: g1]);
	UKIntsEqual([[g groups] count], 1);
	UKIntsEqual([[g1 members] count], 3);

	[g2 addMember: o1];
	[g2 addMember: o4];
	UKTrue([g addGroup: g2]);
	UKIntsEqual([[g groups] count], 2);
	UKIntsEqual([[g2 members] count], 2);

	UKTrue([g addGroup: g3]);
	UKIntsEqual([[g groups] count], 3);
	UKIntsEqual([[g3 members] count], 0);

	UKTrue([g1 addGroup: gg1]);
	UKIntsEqual([[g1 members] count], 4);
	UKIntsEqual([[g1 groups] count], 1);

	UKIntsEqual([[g members] count], 7);
	UKIntsEqual([[g allObjects] count], 8);
	UKIntsEqual([[g groups] count], 3);
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

	/* We don't need mutable option here. COMultiValue should handle it. */
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
	COGroup *group = [COGroup objectWithPropertyList: pl];
	UKTrue([group isKindOfClass: [COGroup class]]);
	UKIntsEqual([[group members] count], 7);
	UKIntsEqual([[group allObjects] count], 8);
	UKIntsEqual([[group groups] count], 3);
	UKIntsEqual([[group allGroups] count], 4);
}

- (void) testProperties
{
	/* Let's make sure COGroup inherit from COObject */
	UKIntsEqual(kCOStringProperty, [COGroup typeOfProperty: kCOUIDProperty]);
	UKIntsEqual(kCOIntegerProperty, [COGroup typeOfProperty: kCOReadOnlyProperty]);
	/* And our own property */
	UKIntsEqual(kCOArrayProperty, [COGroup typeOfProperty: kCOGroupChildrenProperty]);
}

// TODO: Move these faulting related tests into TestFaulting class presently 
// part of TestObjectServer.m

- (void) testResolveFaults
{
	/* Test resolving child objects */
	
	[g setHasFaults: YES];
	// -resolvedFaults calls -[COObjectContext resolvedObjectForFault:]
	[[COObjectContext currentContext] registerObject: g];

	NSMutableArray *gChildren = [g valueForProperty: kCOGroupChildrenProperty];

	// -addMember: triggers -resolveFaults, this would resolve o2 now
	[gChildren addObject: o1];
	[gChildren addObject: [o2 UUID]];
	[[COObjectContext currentContext] registerObject: o2]; // cache o2
	[gChildren addObject: [o3 UUID]];
	/* Don't register o3 so -[COObjectContext resolvedObjectForFault:] returns nil */
	[gChildren addObject: o4];
	[gChildren addObject: [ETUUID UUID]];

	/* o3 and [ETUUID UUID] for which no object exists will result in a warning 
	   being logged each time -resolveFaults is called, and also the following 
	   deserialization failure:
	   File NSMapTable.m: 364. In NSMapGet Nul table argument supplied */
	[g resolveFaults];

	NSArray *childObjects = [g valueForProperty: kCOGroupChildrenProperty];
	UKObjectsSame(o1, [childObjects objectAtIndex: 0]);
	UKObjectsSame(o2, [childObjects objectAtIndex: 1]);
	UKObjectsEqual([o3 UUID], [childObjects objectAtIndex: 2]);
	// FIXME: Fix UnitKit, should be UKObjectKindOf(ETUUID, [childObjects objectAtIndex: 3]);
	UKObjectKindOf([childObjects objectAtIndex: 4], ETUUID);
	UKIntsEqual(5, [childObjects count]);

	/* Test resolving child groups */
	DESTROY(g);
	g = [[COGroup alloc] init];
	[g setHasFaults: YES];
	[[COObjectContext currentContext] registerObject: g];
		
	[g addGroup: g1];
	[g addGroup: (id)[g2 UUID]];
	[[COObjectContext currentContext] registerObject: g2];
	[g addGroup: (id)[g3 UUID]];
	[g addGroup: gg1];
	[g addGroup: [ETUUID UUID]];

	[g resolveFaults];

	childObjects = [g valueForProperty: kCOGroupSubgroupsProperty];
	UKObjectsSame(g1, [childObjects objectAtIndex: 0]);
	UKObjectsSame(g2, [childObjects objectAtIndex: 1]);
	UKObjectsEqual([g3 UUID], [childObjects objectAtIndex: 2]);
	UKObjectKindOf([childObjects objectAtIndex: 4], ETUUID);
	UKIntsEqual(5, [childObjects count]); // includes gg1
}

- (void) testTryResolveFault
{
	[g setHasFaults: YES];
	// -resolvedFaults calls -[COObjectContext resolvedObjectForFault:]
	[[COObjectContext currentContext] registerObject: g];

	NSMutableArray *gChildren = [g valueForProperty: kCOGroupChildrenProperty];
	//NSMutableArray *gChildGroups= [g valueForProperty: kCOGroupSubgroupsProperty];

	// -addMember: triggers -resolveFaults, this would resolve o2 now
	[gChildren addObject: o1];
	[gChildren addObject: [o2 UUID]];
	[[COObjectContext currentContext] registerObject: o2]; // cache o2
	[gChildren addObject: [o3 UUID]];
	/* Don't register o3 so -[COObjectContext resolvedObjectForFault:] returns nil */
	[gChildren addObject: o4];
	id uuid = [ETUUID UUID];
	[gChildren addObject: uuid];

	UKFalse([g tryResolveFault: nil]);
	UKFalse([g tryResolveFault: [o1 UUID]]);
	UKTrue([g tryResolveFault: [o2 UUID]]);
	UKFalse([g tryResolveFault: [o3 UUID]]);
	UKFalse([g tryResolveFault: [o4 UUID]]);
	UKFalse([g tryResolveFault: uuid]);
		
	NSArray *childObjects = [g valueForProperty: kCOGroupChildrenProperty];
	UKObjectsSame(o1, [childObjects objectAtIndex: 0]);
	UKObjectsSame(o2, [childObjects objectAtIndex: 1]);
	UKObjectsEqual([o3 UUID], [childObjects objectAtIndex: 2]);
	// FIXME: Fix UnitKit, should be UKObjectKindOf(ETUUID, [childObjects objectAtIndex: 3]);
	UKObjectKindOf([childObjects objectAtIndex: 4], ETUUID);
	UKIntsEqual(5, [childObjects count]);
}

@end
