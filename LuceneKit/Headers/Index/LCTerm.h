#ifndef __LUCENE_INDEX_TERM__
#define __LUCENE_INDEX_TERM__

#include <Foundation/Foundation.h>

@interface LCTerm: NSObject <NSCopying>
{
	NSString *field;
	NSString *text;
}

- (id) initWithField: (NSString *) fld text: (NSString *) txt;
- (NSString *) field;
- (NSString *) text;
- (void) setField: (NSString *) field;
- (void) setText: (NSString *) text;
- (void) setTerm: (LCTerm *) other;
- (NSComparisonResult) compare: (LCTerm *) other;

@end

#endif /* __LUCENE_INDEX_TERM__ */
