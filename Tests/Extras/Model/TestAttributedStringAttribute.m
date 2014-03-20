/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringAttribute : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedStringAttribute

- (void) testEqualsAndMinusConvenienceMethods
{
	COObjectGraphContext *graph1 = [COObjectGraphContext new];
	
	COAttributedStringAttribute *attr1a = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: graph1];
	attr1a.styleKey = @"text-decoration";
	attr1a.styleValue = @"line-through";
	
	COAttributedStringAttribute *attr1b = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: graph1];
	attr1b.styleKey = @"text-decoration";
	attr1b.styleValue = @"underline";
	
	COObjectGraphContext *graph2 = [COObjectGraphContext new];
	
	COAttributedStringAttribute *attr2a = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: graph2];
	attr2a.styleKey = @"text-decoration";
	attr2a.styleValue = @"line-through";
	
	UKFalse([COAttributedStringAttribute isAttributeSet: S(attr1a, attr1b) equalToSet: S(attr2a)]);
	UKFalse([COAttributedStringAttribute isAttributeSet: S(attr1b) equalToSet: S(attr2a)]);
	UKFalse([COAttributedStringAttribute isAttributeSet: S() equalToSet: S(attr2a)]);
	UKFalse([COAttributedStringAttribute isAttributeSet: S(attr1b) equalToSet: S()]);
	
	UKTrue([COAttributedStringAttribute isAttributeSet: S(attr1a) equalToSet: S(attr2a)]);
	UKTrue([COAttributedStringAttribute isAttributeSet: S(attr2a) equalToSet: S(attr2a)]);
	
	UKObjectsEqual(S(attr1b), [COAttributedStringAttribute attributeSet: S(attr1a, attr1b) minusSet: S(attr2a)]);
	UKObjectsEqual(S(attr1a, attr1b), [COAttributedStringAttribute attributeSet: S(attr1a, attr1b) minusSet: S()]);
}

@end
