#import "TestCommon.h"

ETUUID *AttributedString1UUID();
ETUUID *AttributedString2UUID();

@interface EditingContextTestCase (TestAttributedStringCommon)

- (COAttributedStringAttribute *)makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx;
- (void)addHtmlCode: (NSString *)code toChunk: (COAttributedStringChunk *)aChunk;
- (COObjectGraphContext *)makeAttributedString;
/**
 * Parses the given HTML and turns it in to a COAttributedString.
 * Always makes a COAttributedString with the same UUID.
 */
- (COObjectGraphContext *)makeAttributedStringWithHTML: (NSString *)html;
/**
 * Same as -makeAttributedStringWithHTML: but uses a different UUID
 */
- (COObjectGraphContext *)makeAttributedString2WithHTML: (NSString *)html;
- (void)clearAttributedString: (COAttributedString *)dest;
- (COAttributedStringChunk *)appendString: (NSString *)string
                                htmlCodes: (NSArray *)codes
                       toAttributedString: (COAttributedString *)dest;
- (COAttributedStringChunk *)appendString: (NSString *)string
                                 htmlCode: (NSString *)aCode
                       toAttributedString: (COAttributedString *)dest;
- (void)   checkAttribute: (NSString *)attributeName
                 hasValue: (id)expectedValue
withLongestEffectiveRange: (NSRange)expectedRange
       inAttributedString: (NSAttributedString *)target;
- (void)checkFontHasTraits: (NSFontSymbolicTraits)traits
 withLongestEffectiveRange: (NSRange)expectedRange
        inAttributedString: (NSAttributedString *)target;
- (void)setFontTraits: (NSFontSymbolicTraits)traits
              inRange: (NSRange)aRange
        inTextStorage: (NSTextStorage *)target;
- (void)appendHTMLString: (NSString *)html toAttributedString: (COAttributedString *)dest;
- (void)checkMergingBase: (NSString *)base
             withBranchA: (NSString *)branchA
             withBranchB: (NSString *)branchB
                   gives: (NSString *)result;
- (void)checkAttributedString: (NSAttributedString *)attrStr equalsHTML: (NSString *)html;
- (void)checkCOAttributedString: (COAttributedString *)coAttrStr equalsHTML: (NSString *)html;


#pragma mark - test infrastructure


- (void)checkDiffHTML: (NSString *)stringA
             withHTML: (NSString *)stringB
      givesOperations: (NSSet *)aSet;
- (id <COAttributedStringDiffOperation>)insertHTML: (NSString *)aString atIndex: (NSUInteger)index;
- (id <COAttributedStringDiffOperation>)replaceRangeOp: (NSRange)aRange
                                              withHTML: (NSString *)aString;
- (id <COAttributedStringDiffOperation>)deleteRangeOp: (NSRange)aRange;
- (id <COAttributedStringDiffOperation>)addAttributeOp: (NSString *)aString
                                               inRange: (NSRange)aRange;
- (id <COAttributedStringDiffOperation>)removeAttributeOp: (NSString *)aString
                                                  inRange: (NSRange)aRange;

@end
