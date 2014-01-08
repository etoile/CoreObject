#import "TestCommon.h"

@interface TestAttributedStringCommon : EditingContextTestCase

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx;

- (void) addHtmlCode: (NSString *)code toChunk: (COAttributedStringChunk *)aChunk;

- (COObjectGraphContext *) makeAttributedString;

- (void) clearAttributedString: (COAttributedString *)dest;

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCodes: (NSArray *)codes toAttributedString: (COAttributedString *)dest;

- (COAttributedStringChunk *) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest;

- (void) checkAttribute: (NSString *)attributeName hasValue: (id)expectedValue withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target;

- (void) checkFontHasTraits: (NSFontSymbolicTraits)traits withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target;

@end
