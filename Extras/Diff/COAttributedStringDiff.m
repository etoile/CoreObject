#import "COAttributedStringDiff.h"
#import "COAttributedStringWrapper.h"
#include "diff.h"

@implementation COAttributedStringDiff

@synthesize operations = _operations;

static bool arraycomparefn(size_t i, size_t j, const void *userdata1, const void *userdata2)
{
	return [(__bridge NSString *)userdata1 characterAtIndex: i]
	== [(__bridge NSString *)userdata2 characterAtIndex: j];
}
	
- (instancetype) initWithFirstAttributedString: (COAttributedString *)first
						secondAttributedString: (COAttributedString *)second
										source: (id)source
{
	SUPERINIT;
	
	_first = first;
	_second = second;
	_source = source;
	_operations = [NSMutableArray new];
	
	NSString *firstString = [[[COAttributedStringWrapper alloc] initWithBacking: _first] string];
	NSString *secondString = [[[COAttributedStringWrapper alloc] initWithBacking: _second] string];
	
	diffresult_t *result = diff_arrays([firstString length], [secondString length], arraycomparefn, (__bridge void *)firstString, (__bridge void *)secondString);
	
	for (size_t i = 0; i < diff_editcount(result); i++)
	{
		const diffedit_t edit = diff_edit_at_index(result, i);
		const NSRange rangeInA = NSMakeRange(edit.range_in_a.location, edit.range_in_a.length);
		const NSRange rangeInB = NSMakeRange(edit.range_in_b.location, edit.range_in_b.length);
		
		switch (edit.type)
		{
			case difftype_insertion:
				[self recordInsertionRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_deletion:
				[self recordDeletionRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_modification:
				[self recordModificationRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_copy:
				[self recordCopyRangeA: rangeInA rangeB: rangeInB];
				break;
		}
	}
	
	diff_free(result);
	
	return self;
}

- (void) recordInsertionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	COItemGraph *graph = [_second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
	op.range = rangeInA;
	op.source = _source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordDeletionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	COAttributedStringDiffOperationDeleteRange *op = [COAttributedStringDiffOperationDeleteRange new];
	op.range = rangeInA;
	op.source = _source;
	
	[_operations addObject: op];
}

- (void) recordModificationRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	// The semantics of "modification" are that the old and new
	// block are totally unrelated. Thus the old and new attributes
	// are totally semantically unrelated, so we just record it in the diff as
	// 'replace this range with this new attributed string'
	
	COItemGraph *graph = [_second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationReplaceRange *op = [COAttributedStringDiffOperationReplaceRange new];
	op.range = rangeInA;
	op.source = _source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordCopyRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	// The textual content of these regions is unchanged. Iterate
	// through the attributes and see if they are the same too.
	
	assert(rangeInA.length == rangeInB.length);
	
	// FIXME: Implement
}


@end


@implementation COAttributedStringDiffOperationInsertAttributedSubstring
@synthesize range, source, attributedStringItemGraph;
@end

@implementation COAttributedStringDiffOperationDeleteRange
@synthesize range, source;
@end

@implementation COAttributedStringDiffOperationReplaceRange
@synthesize range, source, attributedStringItemGraph;
@end

@implementation COAttributedStringDiffOperationAddAttribute
@synthesize range, source, attributeItemGraph;
@end

@implementation COAttributedStringDiffOperationRemoveAttribute
@synthesize range, source, attributeItemGraph;
@end
