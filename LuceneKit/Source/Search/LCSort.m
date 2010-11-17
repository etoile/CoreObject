#include "LCSort.h"
#include "GNUstep.h"

/**
* Encapsulates sort criteria for returned hits.
 *
 * <p>The fields used to determine sort order must be carefully chosen.
 * Documents must contain a single term in such a field,
 * and the value of the term should indicate the document's relative position in
 * a given sort order.  The field must be indexed, but should not be tokenized,
 * and does not need to be stored (unless you happen to want it back with the
								   * rest of your document data).  In other words:
 *
 * <p><code>document.add (new Field ("byNumber", Integer.toString(x), Field.Store.NO, Field.Index.UN_TOKENIZED));</code></p>
 * 
 *
 * <p><h3>Valid Types of Values</h3>
 *
 * <p>There are three possible kinds of term values which may be put into
 * sorting fields: Integers, Floats, or Strings.  Unless
 * {@link SortField SortField} objects are specified, the type of value
 * in the field is determined by parsing the first term in the field.
 *
 * <p>Integer term values should contain only digits and an optional
 * preceeding negative sign.  Values must be base 10 and in the range
 * <code>Integer.MIN_VALUE</code> and <code>Integer.MAX_VALUE</code> inclusive.
 * Documents which should appear first in the sort
 * should have low value integers, later documents high values
 * (i.e. the documents should be numbered <code>1..n</code> where
	* <code>1</code> is the first and <code>n</code> the last).
 *
 * <p>Float term values should conform to values accepted by
 * {@link Float Float.valueOf(String)} (except that <code>NaN</code>
										* and <code>Infinity</code> are not supported).
 * Documents which should appear first in the sort
 * should have low values, later documents high values.
 *
 * <p>String term values can contain any valid String, but should
 * not be tokenized.  The values are sorted according to their
 * {@link Comparable natural order}.  Note that using this type
 * of term value has higher memory requirements than the other
 * two types.
 *
 * <p><h3>Object Reuse</h3>
 *
 * <p>One of these objects can be
 * used multiple times and the sort order changed between usages.
 *
 * <p>This class is thread safe.
 *
 * <p><h3>Memory Usage</h3>
 *
 * <p>Sorting uses of caches of term values maintained by the
 * internal HitQueue(s).  The cache is static and contains an integer
 * or float array of length <code>IndexReader.maxDoc()</code> for each field
 * name for which a sort is performed.  In other words, the size of the
 * cache in bytes is:
 *
 * <p><code>4 * IndexReader.maxDoc() * (# of different fields actually used to sort)</code>
 *
 * <p>For String fields, the cache is larger: in addition to the
 * above array, the value of every term in the field is kept in memory.
 * If there are many unique terms in the field, this could
 * be quite large.
 *
 * <p>Note that the size of the cache is not affected by how many
 * fields are in the index and <i>might</i> be used to sort - only by
 * the ones actually used to sort a result set.
 *
 * <p>The cache is cleared each time a new <code>IndexReader</code> is
 * passed in, or if the value returned by <code>maxDoc()</code>
 * changes for the current IndexReader.  This class is not set up to
 * be able to efficiently sort hits from more than one index
 * simultaneously.
 *
 * <p>Created: Feb 12, 2004 10:53:57 AM
 *
 * @author  Tim Jones (Nacimiento Software)
 * @since   lucene 1.4
 * @version $Id$
 */
@implementation LCSort

/**
* Represents sorting by computed relevance. Using this sort criteria returns
 * the same results as calling
 * {@link Searcher#search(Query) Searcher#search()}without a sort criteria,
 * only with slightly more overhead.
 */
+ (LCSort *) sort_RELEVANCE
{
	return [[LCSort alloc] init];
}

+ (LCSort *) sort_INDEXORDER
{
	return [[LCSort alloc] initWithSortField: [LCSortField sortField_DOC]];
}

/**
* Sorts by computed relevance. This is the same sort criteria as calling
 * {@link Searcher#search(Query) Searcher#search()}without a sort criteria,
 * only with slightly more overhead.
 */
- (id) init
{
	self = [self initWithSortFields: [NSArray arrayWithObjects: [LCSortField sortField_SCORE], [LCSortField sortField_DOC], nil]];
	return self;
}

/**
* Sorts by the terms in <code>field</code> then by index order (document
																* number). The type of value in <code>field</code> is determined
 * automatically.
 * 
 * @see SortField#AUTO
 */
- (id) initWithField: (NSString *) field
{
	self = [super init];
	[self setField: field reverse: NO];
	return self;
}

/**
* Sorts possibly in reverse by the terms in <code>field</code> then by
 * index order (document number). The type of value in <code>field</code> is
 * determined automatically.
 * 
 * @see SortField#AUTO
 */
- (id) initWithField: (NSString *) field reverse: (BOOL) reverse
{
	self = [super init];
	[self setField: field reverse: reverse];
	return self;
}

/**
* Sorts in succession by the terms in each field. The type of value in
 * <code>field</code> is determined automatically.
 * 
 * @see SortField#AUTO
 */
- (id) initWithFields: (NSArray *) f
{
	self = [super init];
	[self setFields: f];
	return self;
}

/** Sorts by the criteria in the given SortField. */
- (id) initWithSortField: (LCSortField *) field
{
	self = [super init];
	[self setSortField: field];
	return self;
}

/** Sorts in succession by the criteria in each SortField. */
- (id) initWithSortFields: (NSArray *) f
{
	self = [super init];
	[self setSortFields: f];
	return self;
}

- (void) dealloc
{
	DESTROY(fields);
	[super dealloc];
}

/**
* Sets the sort to the terms in <code>field</code> then by index order
 * (document number).
 */
- (void) setField: (NSString *) field
{
	[self setField: field reverse: NO];
}

/**
* Sets the sort to the terms in <code>field</code> possibly in reverse,
 * then by index order (document number).
 */
- (void) setField: (NSString *) field reverse: (BOOL) reverse
{
	LCSortField *sf = [[LCSortField alloc] initWithField: field
													type: LCSortField_AUTO
												 reverse: reverse];
	NSArray *array = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	RELEASE(sf);
	ASSIGN(fields, array);
}

/** Sets the sort to the terms in each field in succession. */
- (void) setFields: (NSArray *) f
{
	int i, count = [f count];
	NSMutableArray *array = [[NSMutableArray alloc] init];
	LCSortField *sf;
	for (i = 0; i < count; i++)
	{
		sf = [[LCSortField alloc] initWithField: [f objectAtIndex: i]
										   type: LCSortField_AUTO];
		[array addObject: sf];
		RELEASE(sf);
	}
	ASSIGN(fields, array);
	RELEASE(array);
}

/** Sets the sort to the given criteria. */
- (void) setSortField: (LCSortField *) field
{
	NSArray *array = [NSArray arrayWithObjects: field, nil];
	ASSIGN(fields, array);
}

/** Sets the sort to the given criteria in succession. */
- (void) setSortFields: (NSArray *) f
{
	ASSIGN(fields, f);
}

/**
* Representation of the sort criteria.
 * @return Array of SortField objects used in this sort criteria
 */
- (NSArray *) sortFields
{
	return fields;
}

- (NSString *) description
{
	NSMutableString *s = [[NSMutableString alloc] init];
	int i, count = [fields count];
	for (i = 0; i < count; i++)
	{
		[s appendString: [[fields objectAtIndex: i] description]];
		if ((i+1) < count)
			[s appendString: @","];
	}
	return AUTORELEASE(s);
}

@end
