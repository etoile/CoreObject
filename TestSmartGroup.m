/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "OKSmartGroup.h"
#import "OKObject.h"
#import "OKMultiValue.h"
#import "GNUstep.h"

@interface TestSmartGroup: NSObject <UKTest>
@end

@implementation TestSmartGroup
- (id) init
{
	self = [super init];
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

- (void) testSearchText
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			@"Location",
		[NSNumber numberWithInt: kOKRealProperty], 
			@"Float",
		nil];
	[OKObject addPropertiesAndTypes: dict];

	OKObject *o1 = [[OKObject alloc] init];
	UKTrue([o1 setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o1 setValue: [NSNumber numberWithFloat: 2.12] 
	           forProperty: @"Float"]);

	OKObject *o2 = [[OKObject alloc] init];
	UKTrue([o2 setValue: @"Home" forProperty: @"Location"]);
	UKTrue([o2 setValue: [NSNumber numberWithFloat: 3.12] 
	           forProperty: @"Float"]);

	OKObject *o3 = [[OKObject alloc] init];
	UKTrue([o3 setValue: @"Office" forProperty: @"Location"]);
	UKTrue([o3 setValue: [NSNumber numberWithFloat: 2.12] 
	           forProperty: @"Float"]);

	OKObject *o4 = [[OKObject alloc] init];
	UKTrue([o4 setValue: @"Office" forProperty: @"Location"]);
	UKTrue([o4 setValue: [NSNumber numberWithFloat: 4.12] 
	           forProperty: @"Float"]);

	OKGroup *group = [[OKGroup alloc] init];
	UKTrue([group addObject: o1]);
	UKTrue([group addObject: o2]);
	UKTrue([group addObject: o3]);
	UKTrue([group addObject: o4]);

	OKSmartGroup *smart = [[OKSmartGroup alloc] init];
	NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Home"];
	[smart setPredicate: p];
	[smart setTarget: group];
	UKIntsEqual([[smart objects] count], 2);

	p = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Office"];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 2);

	p = [NSPredicate predicateWithFormat: @"%K == %@", @"Float", [NSNumber numberWithFloat: 2.12]];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 2);

	p = [NSPredicate predicateWithFormat: @"%K < %@", @"Float", [NSNumber numberWithFloat: 4]];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 3);

	/* Test recursive */
	[group addSubgroup: group];
	p = [NSPredicate predicateWithFormat: @"%K == %@", @"Location", @"Office"];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 2);

	p = [NSPredicate predicateWithFormat: @"%K == %@", @"Float", [NSNumber numberWithFloat: 2.12]];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 2);

	p = [NSPredicate predicateWithFormat: @"%K < %@", @"Float", [NSNumber numberWithFloat: 4]];
	[smart setPredicate: p];
	UKIntsEqual([[smart objects] count], 3);

	/* Test update */
	UKTrue([o2 setValue: [NSNumber numberWithFloat: 4.12] 
	           forProperty: @"Float"]);
	UKIntsEqual([[smart objects] count], 2);
}

@end
