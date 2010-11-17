#ifndef __LUCENE_INDEX_TERM_DOCS__
#define __LUCENE_INDEX_TERM_DOCS__

#include <Foundation/Foundation.h>
#include "LCTerm.h"
#include "LCTermEnum.h"

/** TermDocs provides an interface for enumerating &lt;document, frequency&gt;
pairs for a term.  <p> The document portion names each document containing
the term.  Documents are indicated by number.  The frequency portion gives
the number of times the term occurred in each document.  <p> The pairs are
ordered by document number.

@see IndexReader#termDocs()
*/

@protocol LCTermDocuments <NSObject>
/** Sets this to the data for a term.
* The enumeration is reset to the start of the data for this term.
*/
- (void) seekTerm: (LCTerm *) term;

	/** Sets this to the data for the current term in a {@link TermEnum}.
	* This may be optimized in some implementations.
	*/
- (void) seekTermEnumerator: (LCTermEnumerator *) termEnum;

	/** Returns the current document number.  <p> This is invalid until {@link
#next()} is called for the first time.*/
- (long) document;  // VInt

	/** Returns the frequency of the term within the current document.  <p> This
	is invalid until {@link #next()} is called for the first time.*/
- (long) frequency;  // VInt

	/** Moves to the next pair in the enumeration.  <p> Returns true iff there is
	such a next pair in the enumeration. */
- (BOOL) hasNextDocument;

	/** Attempts to read multiple entries from the enumeration, up to length of
	* <i>docs</i>.  Document numbers are stored in <i>docs</i>, and term
	* frequencies are stored in <i>freqs</i>.  The <i>freqs</i> array must be as
	* long as the <i>docs</i> array.
	*
	* <p>Returns the number of entries read.  Zero is only returned when the
	* stream has been exhausted.  */
- (int) readDocuments: (NSMutableArray *) docs frequency: (NSMutableArray *) freqs
				 size: (int) size;

	/** Skips entries to the first beyond the current whose document number is
	* greater than or equal to <i>target</i>. <p>Returns true iff there is such
   * an entry.  <p>Behaves as if written: <pre>
	*   boolean skipTo(int target) {
		*     do {
			*       if (!next())
				* 	     return false;
			*     } while (target > doc());
		*     return true;
		*   }
	* </pre>
	* Some implementations are considerably more efficient than that.
	*/
- (BOOL) skipTo: (int) target;

	/** Frees associated resources. */
- (void) close;

@end

#endif /* __LUCENE_INDEX_TERM_DOCS__ */
