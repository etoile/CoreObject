/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "OKMultiValue.h"
#import "GNUstep.h"
#import <UnitKit/UnitKit.h>

@interface TestMultiValue: NSObject <UKTest>
{
	OKMultiValue *mv;
}
@end

@implementation TestMultiValue
- (id) init
{
	self = [super init];
	mv = [[OKMultiValue alloc] init];
	[mv addValue: @"value0" withLabel: @"label0"];
	[mv addValue: @"value1" withLabel: @"label1"];
	[mv setPrimaryIdentifier: [mv identifierAtIndex: 0]];
	return self;
}

- (void) dealloc
{
	DESTROY(mv);
	[super dealloc];
}

- (void) testConsistency
{
	UKStringsNotEqual([mv identifierAtIndex: 0], [mv identifierAtIndex: 1]);
}

- (void) testPropertyList
{
	id pl = [mv propertyList];
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

	OKMultiValue *vv = [[OKMultiValue alloc] initWithPropertyList: pl];
	UKStringsEqual([mv primaryIdentifier], [vv primaryIdentifier]);
	[mv setPrimaryIdentifier: [mv identifierAtIndex: 1]];
	UKStringsNotEqual([mv primaryIdentifier], [vv primaryIdentifier]);
	UKStringsEqual([mv valueAtIndex: 0], [vv valueAtIndex: 0]);
	[vv replaceValueAtIndex: 0 withValue: @"value_not_0"];
	UKStringsNotEqual([mv valueAtIndex: 0], [vv valueAtIndex: 0]);
}

- (void) testMultiValue
{
	UKStringsEqual(@"value0", [mv valueAtIndex: 0]);
	UKStringsEqual(@"value1", [mv valueAtIndex: 1]);
	UKStringsEqual(@"label0", [mv labelAtIndex: 0]);
	UKStringsEqual(@"label1", [mv labelAtIndex: 1]);
	UKTrue([mv replaceValueAtIndex: 0 withValue: @"NewValue0"]); 
	UKTrue([mv replaceValueAtIndex: 1 withValue: @"NewValue1"]); 
	UKStringsEqual(@"NewValue0", [mv valueAtIndex: 0]);
	UKStringsEqual(@"NewValue1", [mv valueAtIndex: 1]);
	UKStringsEqual(@"label0", [mv labelAtIndex: 0]);
	UKStringsEqual(@"label1", [mv labelAtIndex: 1]);
}

- (void) testInsertAndReplace
{
	NSString *iden = [mv insertValue: @"insertValue" withLabel: @"insertLabel" atIndex: 1];
	UKNotNil(iden);
	UKIntsEqual(1, [mv indexForIdentifier: iden]);

	UKStringsEqual(@"value0", [mv valueAtIndex: 0]);
	UKStringsEqual(@"insertValue", [mv valueAtIndex: 1]);
	UKStringsEqual(@"value1", [mv valueAtIndex: 2]);
	UKStringsEqual(@"label0", [mv labelAtIndex: 0]);
	UKStringsEqual(@"insertLabel", [mv labelAtIndex: 1]);
	UKStringsEqual(@"label1", [mv labelAtIndex: 2]);
	UKIntsEqual([mv count], 3);
	UKTrue([mv removeValueAndLabelAtIndex: 2]);
	UKIntsEqual([mv count], 2);
	UKStringsEqual(@"value0", [mv valueAtIndex: 0]);
	UKStringsEqual(@"insertValue", [mv valueAtIndex: 1]);
	UKStringsEqual(@"label0", [mv labelAtIndex: 0]);
	UKStringsEqual(@"insertLabel", [mv labelAtIndex: 1]);
}

- (void) testCopy
{
	OKMultiValue *v = [mv copy];
	UKNotNil(v);
	UKStringsEqual(@"value0", [v valueAtIndex: 0]);
	UKStringsEqual(@"value1", [v valueAtIndex: 1]);
	UKStringsEqual(@"label0", [v labelAtIndex: 0]);
	UKStringsEqual(@"label1", [v labelAtIndex: 1]);
	UKTrue([mv replaceValueAtIndex: 0 withValue: @"NewValue0"]); 
	UKTrue([mv replaceValueAtIndex: 1 withValue: @"NewValue1"]); 
	UKStringsEqual(@"value0", [v valueAtIndex: 0]);
	UKStringsEqual(@"value1", [v valueAtIndex: 1]);
	UKStringsEqual(@"label0", [v labelAtIndex: 0]);
	UKStringsEqual(@"label1", [v labelAtIndex: 1]);
	DESTROY(v);
}

- (void) testMutableCopy
{
	OKMultiValue *v = [mv copy];
	UKNotNil(v);
	OKMultiValue *vv = [v copy];
	UKNotNil(vv);
	UKStringsEqual(@"value0", [vv valueAtIndex: 0]);
	UKStringsEqual(@"value1", [vv valueAtIndex: 1]);
	UKStringsEqual(@"label0", [vv labelAtIndex: 0]);
	UKStringsEqual(@"label1", [vv labelAtIndex: 1]);
	UKTrue([vv replaceValueAtIndex: 0 withValue: @"NewValue0"]); 
	UKTrue([vv replaceValueAtIndex: 1 withValue: @"NewValue1"]); 
	UKStringsEqual(@"NewValue0", [vv valueAtIndex: 0]);
	UKStringsEqual(@"NewValue1", [vv valueAtIndex: 1]);
	UKStringsEqual(@"label0", [vv labelAtIndex: 0]);
	UKStringsEqual(@"label1", [vv labelAtIndex: 1]);

	UKStringsEqual(@"value0", [v valueAtIndex: 0]);
	UKStringsEqual(@"value1", [v valueAtIndex: 1]);
	UKStringsEqual(@"label0", [v labelAtIndex: 0]);
	UKStringsEqual(@"label1", [v labelAtIndex: 1]);

	DESTROY(v);
}

- (void) testIdentifierAndType
{
	OKMultiValue *v = [mv copy];
	UKNotNil(v);
	UKNotNil([mv primaryIdentifier]);
	UKNotNil([v primaryIdentifier]);
	UKStringsEqual([v primaryIdentifier], [mv primaryIdentifier]);
	int d = [mv indexForIdentifier: [mv primaryIdentifier]];
	UKStringsEqual([v primaryIdentifier], [v identifierAtIndex: d]);
	[mv setPrimaryIdentifier: [mv identifierAtIndex: 1]];
	UKStringsNotEqual([v primaryIdentifier], [mv primaryIdentifier]);
	DESTROY(v);
}

@end

