/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringWrapper : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedStringWrapper

- (void) checkAttribute: (NSString *)attributeName hasValue: (id)expectedValue withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target
{
	NSRange actualRange;
	id actualValue = [target attribute: attributeName atIndex: expectedRange.location effectiveRange: &actualRange];
	
	if (expectedValue == nil)
	{
		UKNil(actualValue);
	}
	else
	{
		UKObjectsEqual(expectedValue, actualValue);
	}
	
	UKIntsEqual(expectedRange.location, actualRange.location);
	UKIntsEqual(expectedRange.length, actualRange.length);
}

- (void) testWrapperBasic
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"X" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"Y" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *wrapper = [COAttributedStringWrapper new];
	wrapper.backing = [source rootObject];
			
	UKIntsEqual(2, [wrapper length]);
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: wrapper];
	
	// TODO: Check bold font
}

- (void) testWrapperInsertCharacters
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [COAttributedStringWrapper new];
	as.backing = [source rootObject];
	
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"test"];
	
	UKObjectsEqual(@"(test)", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 6) inAttributedString: as];
}

- (void) testWrapperReplaceCharacters
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [COAttributedStringWrapper new];
	as.backing = [source rootObject];
	
	[as replaceCharactersInRange: NSMakeRange(1, 1) withString: @">"];
	
	UKObjectsEqual(@"(>", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 2) inAttributedString: as];
}

- (void) testWrapperReplaceCharactersAcrossChunks
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"u" toAttributedString: [source rootObject]];
	[self appendString: @"def" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"ghi" htmlCode: @"i" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [COAttributedStringWrapper new];
	as.backing = [source rootObject];
	
	[as replaceCharactersInRange: NSMakeRange(2, 5) withString: @"-"];
	
	UKObjectsEqual(@"ab-hi", [as string]);
}

- (void) testTextStorageNotificationsCalled
{
	// When we modify the text storage backing (e.g. reloading a different graph state), we need to call some notification methods
}

@end
