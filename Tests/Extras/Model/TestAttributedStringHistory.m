/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringHistory : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedStringHistory

- (NSAttributedString *) html: (NSString *)htmlString
{
	return [[NSAttributedString alloc] initWithHTML: [htmlString dataUsingEncoding: NSUTF8StringEncoding]
								 documentAttributes: nil];
}

- (void) testUndo
{
	COUndoTrack *track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
	[track clear];
	
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"COAttributedString"];
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [proot rootObject]];
	[[as mutableString] appendString: @"x"];
	[ctx commit];
	
	[as appendAttributedString: [self html: @"<u>y</u>"]];
	UKObjectsEqual(@"xy", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1,1) inAttributedString: as];
	[ctx commitWithUndoTrack: track];
	
	[track undo];
	
	UKObjectsEqual(@"x", [as string]);
	
	// FIXME: Breaks
	/*
	[track redo];
	
	UKObjectsEqual(@"xy", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1,1) inAttributedString: as];
	 */
}

@end
