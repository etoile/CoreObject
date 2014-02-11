/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringHistory : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedStringHistory

- (NSAttributedString *) html: (NSString *)htmlString
{
	return [[NSAttributedString alloc] initWithHTML: [htmlString dataUsingEncoding: NSUTF8StringEncoding]
								 documentAttributes: nil];
}

- (void) testUndo
{
	// This test was triggering some random failures; so run it 10 times
	for (NSUInteger iters = 0; iters < 10; iters++)
	{
		COUndoTrack *track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
		[track clear];
		
		COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"COAttributedString"];
		COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [proot rootObject]];
		[[as mutableString] appendString: @"x"];
		
		{
			COObjectGraphContext *graph = [proot objectGraphContext];
			COAttributedString *root = [proot rootObject];
			COAttributedStringChunk *chunk0 = root.chunks[0];
			
			// Check that the object graph is correctly constructed
			
			UKObjectsEqual(@"x", chunk0.text);
			UKObjectsEqual(A(chunk0), root.chunks);
			UKObjectsEqual(S(), chunk0.attributes);
			
			// Check that the proper objects are marked as updated and inserted
			
			UKObjectsEqual(S(root.UUID, chunk0.UUID), [graph insertedObjectUUIDs]);
		}
		
		[ctx commit];
		
		[as appendAttributedString: [self html: @"<u>y</u>"]];
		UKObjectsEqual(@"xy", [as string]);
		[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1,1) inAttributedString: as];
		
		
		{
			COObjectGraphContext *graph = [proot objectGraphContext];
			COAttributedString *root = [proot rootObject];
			COAttributedStringChunk *chunk0 = root.chunks[0];
			COAttributedStringChunk *chunk1 = root.chunks[1];
			COAttributedStringAttribute *underlineAttr = [chunk1.attributes anyObject];

			// Check that the object graph is correctly constructed
			
			UKObjectsEqual(@"x", chunk0.text);
			UKObjectsEqual(@"y", chunk1.text);
			//UKObjectsEqual(@"u", underlineAttr.htmlCode);
			UKObjectsEqual(A(chunk0, chunk1), root.chunks);
			UKObjectsEqual(S(), chunk0.attributes);
			UKObjectsEqual(S(underlineAttr), chunk1.attributes);
			
			// Check that the proper objects are marked as updated and inserted
		}
		
		[ctx commitWithUndoTrack: track];
		
		[track undo];
		
		UKObjectsEqual(@"x", [as string]);
		
		[track redo];
		
		UKObjectsEqual(@"xy", [as string]);
		[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1,1) inAttributedString: as];
	}
}

@end
