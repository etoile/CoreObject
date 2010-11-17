#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCBooleanQuery.h"
#include "LCTermQuery.h"
#include "LCTerm.h"

@interface TestBooleanQuery : NSObject <UKTest>
@end

@implementation TestBooleanQuery
- (void) testEquality
{
    LCBooleanQuery *bq1 = [[LCBooleanQuery alloc] init];
	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"value1"];
	LCTermQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	[bq1 addQuery: query occur: LCOccur_SHOULD];
	term = [[LCTerm alloc] initWithField: @"field" text: @"value2"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[bq1 addQuery: query occur: LCOccur_SHOULD];

	LCBooleanQuery *nested1 = [[LCBooleanQuery alloc] init];
	term = [[LCTerm alloc] initWithField: @"field" text: @"nestedvalue1"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[nested1 addQuery: query occur: LCOccur_SHOULD];
	term = [[LCTerm alloc] initWithField: @"field" text: @"nestedvalue2"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[nested1 addQuery: query occur: LCOccur_SHOULD];
	[bq1 addQuery: nested1 occur: LCOccur_SHOULD];
    
    LCBooleanQuery *bq2 = [[LCBooleanQuery alloc] init];
	term = [[LCTerm alloc] initWithField: @"field" text: @"value1"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[bq2 addQuery: query occur: LCOccur_SHOULD];
	term = [[LCTerm alloc] initWithField: @"field" text: @"value2"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[bq2 addQuery: query occur: LCOccur_SHOULD];
	
	LCBooleanQuery *nested2 = [[LCBooleanQuery alloc] init];
	term = [[LCTerm alloc] initWithField: @"field" text: @"nestedvalue1"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[nested2 addQuery: query occur: LCOccur_SHOULD];
	term = [[LCTerm alloc] initWithField: @"field" text: @"nestedvalue2"];
	query = [[LCTermQuery alloc] initWithTerm: term];
	[nested2 addQuery: query occur: LCOccur_SHOULD];
	[bq2 addQuery: nested1 occur: LCOccur_SHOULD];

	UKTrue([bq1 isEqual: bq2]);
}

@end
