#ifndef __LUCENE_UTIL_PRIORITY_QUEUE__
#define __LUCENE_UTIL_PRIORITY_QUEUE__

#include <Foundation/Foundation.h>

/** Used by LCPriorityQueue 
* to decide which one is less (NSOrderedAscending)
*/
@protocol LCComparable <NSObject>
- (NSComparisonResult) compare: (id) other;
@end

/** A PriorityQueue maintains a partial ordering of its objects such that the
least object can always be found in constant time. -put: and -pop:
require log(size) time. */

@interface LCPriorityQueue: NSObject
{
	NSMutableArray *heap;
	int maxSize;
}

/** <init/> Initiate with size */
- (id) initWithSize: (int) size;
/** Put object into queue. If the queue is full, error rise */
- (void) put: (id) object;
/** insert object into queue. 
 * Return YES if succeed (queue is not full or object greater than the -top object in the queue */
- (BOOL) insert: (id) object;
/** return the least object */
- (id) top;
/** Return the least object and remove it from queue */
- (id) pop;
/** Adjust the top object */
- (void) adjustTop;
/** Size of queue */
- (int) size;
/** Removes all objects */
- (void) removeAllObjects;

@end

@interface LCPriorityQueue (LCProtected)
- (BOOL) lessThan: (id) a : (id) b;
@end
#endif /* __LUCENE_UTIL_PRIORITY_QUEUE__ */
