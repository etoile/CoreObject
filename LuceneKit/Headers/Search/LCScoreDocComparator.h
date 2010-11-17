#ifndef __LUCENE_SEARCH_SCORE_DOC_COMPARATOR__
#define __LUCENE_SEARCH_SCORE_DOC_COMPARATOR__

#include <Foundation/Foundation.h>

@class LCScoreDoc;

@protocol LCScoreDocComparator <NSObject>
/**     
* Compares two ScoreDoc objects and returns a result indicating their
* sort order.
* @param i First ScoreDoc
* @param j Second ScoreDoc         
* @return <code>-1</code> if <code>i</code> should come before <code>j</code><br><code>1</code> if <code>i</code> should come after <code>j</code><br><code>0</code> if they are equal
* @see java.util.Comparator
*/      
/* LuceneKit: -1 == NSOrderedAscending, 1 == NSOrderedDescending */
- (NSComparisonResult) compare: (LCScoreDoc *) i to: (LCScoreDoc *) j;
	/**
	* Returns the value used to sort the given document.  The
	 * object returned must implement the java.io.Serializable         * interface.  This is used by multisearchers to determine how to collate results from their searchers.
	 * @see FieldDoc
	 * @param i Document
	 * @return Serializable object
	 */
- (id) sortValue: (LCScoreDoc *) doc;
	/**
	* Returns the type of sort.  Should return <code>SortField.SCORE</code>, <code>SortField.DOC</code>, <code>SortField.STRING</code>, <code>SortField.INTEGER</code>,          
	 * <code>SortField.FLOAT</code> or <code>SortField.CUSTOM</code>.  It is not valid to return <code>SortField.AUTO</code>.         
	 * This is used by multisearchers to determine how to collate results from their searchers.         
	 * @return One of the constants in SortField.         
	 * @see SortField         
	 */        
	/* should be LCSortFieldType */
- (int) sortType;
@end

@interface LCRelevanceScoreDocComparator: NSObject <LCScoreDocComparator>
@end

@interface LCIndexOrderScoreDocComparator: NSObject <LCScoreDocComparator>
@end

#endif /* __LUCENE_SEARCH_SCORE_DOC_COMPARATOR__ */
