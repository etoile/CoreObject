#import "TestCommon.h"

@interface EditingContextTestCase (TestAttributedStringCommon)

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx;

- (void) addHtmlCode: (NSString *)code toChunk: (COAttributedStringChunk *)aChunk;

- (COObjectGraphContext *) makeAttributedString;

/**
 * Parses the given HTML and turns it in to a COAttributedString.
 * Always makes a COAttributedString with the same UUID.
 */
- (COObjectGraphContext *) makeAttributedStringWithHTML: (NSString *)html;
/**
 * Same as -makeAttributedStringWithHTML: but uses a different UUID
 */
- (COObjectGraphContext *) makeAttributedString2WithHTML: (NSString *)html;

- (void) clearAttributedString: (COAttributedString *)dest;

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCodes: (NSArray *)codes toAttributedString: (COAttributedString *)dest;

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest;

- (void) checkAttribute: (NSString *)attributeName hasValue: (id)expectedValue withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target;

- (void) checkFontHasTraits: (NSFontSymbolicTraits)traits withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target;

- (void) setFontTraits: (NSFontSymbolicTraits)traits inRange: (NSRange)aRange inTextStorage: (NSTextStorage *)target;

- (void) appendHTMLString: (NSString *)html toAttributedString: (COAttributedString *)dest;

- (void) checkMergingBase: (NSString *)base
			  withBranchA: (NSString *)branchA
			  withBranchB: (NSString *)branchB
					gives: (NSString *)result;

@end
