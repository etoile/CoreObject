#ifndef __LUCENE_INDEX_TERM_POSITIONS__
#define __LUCENE_INDEX_TERM_POSITIONS__

#include "LCTermDocs.h"
#include "LCPriorityQueue.h"

/**
* TermPositions provides an interface for enumerating the &lt;document,
 * frequency, &lt;position&gt;* &gt; tuples for a term.  <p> The document and
 * frequency are the same as for a TermDocs.  The positions portion lists the ordinal
 * positions of each occurrence of a term in a document.
 *
 * @see IndexReader#termPositions()
 */

@protocol LCTermPositions <LCTermDocuments, LCComparable>
/** Returns next position in the current document.  It is an error to call
this more than {@link #freq()} times
without calling {@link #next()}<p> This is
invalid until {@link #next()} is called for
the first time.
*/
- (int) nextPosition;
@end

#endif /* __LUCENE_INDEX_TERM_POSITIONS__ */
