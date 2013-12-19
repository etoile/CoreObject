#import "COAttributedStringDiff.h"

@implementation COAttributedStringDiff

@synthesize operations = _operations;


- (id) initWithFirstAttributedString: (COAttributedString *)first
              secondAttributedString: (COAttributedString *)second
{
	SUPERINIT;
	return self;
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
