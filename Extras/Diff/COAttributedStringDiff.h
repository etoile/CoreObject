#import <CoreObject/CoreObject.h>
#import "COAttributedString.h"
#import "COAttributedStringChunk.h"
#import "COAttributedStringAttribute.h"

@interface COAttributedStringDiff : NSObject
{
	NSMutableArray *_operations;
}

@property (readonly) NSMutableArray *operations;

- (id) initWithFirstAttributedString: (COAttributedString *)first
              secondAttributedString: (COAttributedString *)second;

@end

@protocol COAttributedStringDiffOperation <NSObject>
@required
@property (nonatomic, readwrite, assign) NSRange range;
@property (nonatomic, readwrite, strong) id source;
@end

@interface COAttributedStringDiffOperationInsertAttributedSubstring : NSObject <COAttributedStringDiffOperation>
@property (nonatomic, readwrite, strong) COItemGraph *attributedStringItemGraph;
@end

@interface COAttributedStringDiffOperationDeleteRange : NSObject <COAttributedStringDiffOperation>
@end

@interface COAttributedStringDiffOperationReplaceRange : NSObject <COAttributedStringDiffOperation>
@property (nonatomic, readwrite, strong) COItemGraph *attributedStringItemGraph;
@end

@interface COAttributedStringDiffOperationAddAttribute : NSObject <COAttributedStringDiffOperation>
@property (nonatomic, readwrite, strong) COItemGraph *attributeItemGraph;
@end

@interface COAttributedStringDiffOperationRemoveAttribute : NSObject <COAttributedStringDiffOperation>
@property (nonatomic, readwrite, strong) COItemGraph *attributeItemGraph;
@end
