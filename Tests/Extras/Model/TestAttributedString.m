/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestAttributedString : TestCase <UKTest>
@end

@implementation TestAttributedString

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx
{
	COAttributedStringAttribute *attribute = [ctx insertObjectWithEntityName: @"COAttributedStringAttribute"];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (void) testMerge
{
	/*
	 ctx1:
	 
	 "abc"
	 	 
	 */
	
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COAttributedString *ctx1String = [ctx1 insertObjectWithEntityName: @"COAttributedString"];
	COAttributedStringChunk *ctx1Chunk1 = [ctx1 insertObjectWithEntityName: @"COAttributedStringChunk"];
		
	ctx1.rootObject = ctx1String;
	ctx1String.chunks = @[ctx1Chunk1];
	ctx1Chunk1.text = @"abc";
	
	/*
	 ctx2:
	 
	 "abc"
	  ^^
	  bold
	 
	 */
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	COAttributedString *ctx2String = ctx2.rootObject;
	COAttributedStringChunk *ctx2Chunk1 = ctx2String.chunks[0];
	COAttributedStringChunk *ctx2Chunk2 = [ctx2 insertObjectWithEntityName: @"COAttributedStringChunk"];
	
	ctx2String.chunks = @[ctx2Chunk1, ctx2Chunk2];
	ctx2Chunk1.text = @"ab";
	ctx2Chunk1.attributes = S([self makeAttr: @"b" inCtx: ctx2]);
	ctx2Chunk2.text = @"c";

	/*
	 ctx3:
	 
	 "dabc"
	    ^^
	    italic
	 
	 */

	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	COAttributedString *ctx3String = ctx3.rootObject;
	COAttributedStringChunk *ctx3Chunk1 = ctx3String.chunks[0];
	COAttributedStringChunk *ctx3Chunk2 = [ctx3 insertObjectWithEntityName: @"COAttributedStringChunk"];
	
	ctx3String.chunks = @[ctx3Chunk1, ctx3Chunk2];
	ctx3Chunk1.text = @"da";
	ctx3Chunk2.text = @"bc";
	ctx3Chunk2.attributes = S([self makeAttr: @"i" inCtx: ctx3]);
	
	COAttributedStringWrapper *wrapper = [COAttributedStringWrapper new];
	wrapper.backing = ctx3String;

	[[wrapper RTFFromRange: NSMakeRange(0, [wrapper length]) documentAttributes: nil]
	 writeToFile: [@"~/test.rtf" stringByExpandingTildeInPath]
	 atomically: YES];
	
//	[ctx1 showGraph];
//	[ctx2 showGraph];
//	[ctx3 showGraph];
	
//	COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
//    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	
//	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
//	
//	COObjectGraphContext *ctxMerged = [COObjectGraphContext new];
//	[ctxMerged setItemGraph: ctx1];
//	[merged applyTo: ctxMerged];
	
	/*
	 ctxExpected:
	 
	 "dabc"
	   ^^
	   bold
	    ^^
		italic
	   
	 Note that the merge process will introduce new objects when it splits chunks, so we can't
	 just build the expected object graph ahead of time but have to do the merge and inspect
	 the result.
	 
	 */
	
	UKPass();
}

@end
