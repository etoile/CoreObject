#import <Foundation/Foundation.h>
#import "COSequenceDiff.h"

@interface COStringDiff : COSequenceDiff
{
}

- (id) initWithFirstString: (NSString *)first
              secondString: (NSString *)second;

- (void) applyTo: (NSMutableString*)string;
- (NSString *)stringWithDiffAppliedTo: (NSString*)string;
// - (void) applyToAttributedString: (NSMutableAttributedString*)string;
// - (NSAttributedString *)attributedStringWithDiffAppliedTo: (NSString*)string;

@end




@interface COStringDiffOperationInsert : COSequenceDiffOperation 
{
	NSString *insertedString;
}

@property (nonatomic, retain, readonly) NSString* insertedString;

+ (COStringDiffOperationInsert*)insertWithLocation: (NSUInteger)loc string: (NSString*)string;

@end


@interface COStringDiffOperationDelete : COSequenceDiffOperation
{
}

+ (COStringDiffOperationDelete*)deleteWithRange: (NSRange)range;

@end


@interface COStringDiffOperationModify : COSequenceDiffOperation
{
	NSString *insertedString;
}

@property (nonatomic, retain, readonly) NSString* insertedString;

+ (COStringDiffOperationModify*)modifyWithRange: (NSRange)range newString: (NSString*)string;

@end
