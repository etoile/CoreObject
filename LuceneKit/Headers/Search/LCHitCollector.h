#ifndef __LUCENE_SEARCH_HIT_COLLECTOR__
#define __LUCENE_SEARCH_HIT_COLLECTOR__

#include <Foundation/Foundation.h>

@interface LCHitCollector: NSObject
{
	id target;
	SEL selector;
}
- (void) collect: (int) doc score: (float) score;

/* LuceneKit: 
 * Implement -collect:score: in the classes which use LCHitCollector
 * and assign target and selector.
 * This is a work-around for in-class subclass in Java.
 */
- (void) setTarget: (id) target;
- (void) setSelector: (SEL) selector;
- (id) target;
- (SEL) selector;
@end

#endif /* __LUCENE_SEARCH_HIT_COLLECTOR__ */
