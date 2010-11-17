#ifndef __LuceneKit_Index_Manager__
#define __LuceneKit_Index_Manager__

#include "LCImporter.h"
#include "LCDirectory.h"
#include "LCDocument.h"
#include "LCAnalyzer.h"
#include "LCIndexModifier.h"
#include "LCQuery.h"

/** LCIndexManager try to bridge GNUstep and Lucene.
 * Currently it is designed to work on file system,
 * but conceptually it should work on URL and database,
 * as long as there is a commony way to access these data in GNUstep (See LCDirectory).
 */

@interface LCIndexManager: LCIndexModifier
{
	NSMutableArray *importers;
	NSMutableArray *paths;
	NSMutableDictionary *pairs;
}

/** Check whether an index is existed at path */
+ (BOOL) indexExistsAtPath: (NSString *) path;

/** Initiate an index data in memory */
- (id) init;

/** Initiate an index data at path.
 * If create is YES and path doesn't exist, a new index data (directory) will be created.
 * If create is NO and paht doesn't exist, it will return nil.
 * If create is YES and path exists, the path will be removed and new index will be created.
 * If create is NO, path exists and is indeed an index data, it will used.
 * If create is NO, path exists and is not an index data, it will return nil;
 */
- (id) initWithPath: (NSString *) path create: (BOOL) create;

/** Use Lucene LCDirectory as virtual file system */
- (id) initWithDirectory: (id <LCDirectory>) directory create: (BOOL) create;

/** Add path for indexing.
 * This is not stored in index, therefore, for each new LCIndexManager,
 * it must be set before use LCIndexManager.
 * Otherwise, nothing will be indexed.
 * If path is a directory, it will index everything within this directory and its subdirectory.
 */
- (void) addIndexPath: (NSString *) path;
/** Set indexPaths */
- (void) setIndexPaths: (NSArray *) paths;
/** return indexPaths */
- (NSArray *) indexPaths;

/** Add importer for indexing.
 * Each file (item) in path will be indexed by each importer.
 * If two importers use the same file type,
 * each file will be indexed twice.
 * It is the responsibility of importer to know which type of file it should handle.
 */
- (void) addImporter: (id <LCImporter>) importer;
- (void) setImporters: (NSArray *) importers;
- (NSArray *) importers;

/** Specify importers for a given path.
 * This override the general rules of indexing above.
 * Only the specified importers will be used for path and its subdirectory (if sub is YES).
 * If importers is nil, path will not be indexed.
 */
- (void) setIndexPath: (NSString *) path importers: (NSArray *) importers includeSubpaths: (BOOL) sub;

/** index everything under -indexPaths.
 * It search all the existed document under -indexPaths, remove them, and add them back.
 * Warn: it cost a lot. It do search and delete, add index if necessary.
 */
- (void) indexAllFiles;
/** index new.
 * It compare the value of updateAttributes to determine whether a file should be indexed.
 * Warn: it cost a lot. It do search, compare and delete, add, index if necessary.
 */
- (void) indexUpdatedFiles;

/** Index one file
 * This should be used most commonly within any application while an file (item) changed.
 * It is basically a combination of -setIndexPaths: and -indexAll.
 * Since there is only one file at a time, the cost is less. 
 */
- (void) indexAtPath: (NSString *) path;
/** Index one file with importer
 */
- (void) indexAtPath: (NSString *) path importer: (id <LCImporter>) importer;

/** Remove the document at path.
 * It do search, delete.
 */
- (void) removeMetadataAtPath: (NSString *) path;

/* Search */
/** Return search result based on query.
 * Return an array of values at keyAttribute.
 */
- (NSArray *) searchWithString: (NSString *) query;
/** Return search result based on query. */
- (NSArray *) searchWithQuery: (LCQuery *) query;

/* Low-level function */
/** Return indexReader.
 * IndexReader and IndexWriter cannot exist at the same time.
 * When one is called, the other is closed by IndexManager.
 * Do not close indexReader or indexWriter on you own.
 * But when you have any of them, do not use the other one because it is closed.
 */
- (LCIndexReader *) indexReader;
/** Return indexWriter. See -indexReader */
- (LCIndexWriter *) indexWriter;
/** Return LCDocument at path */
- (LCDocument *) documentAtPath: (NSString *) path;
/** default analyzer */
- (void) setAnalyzer: (LCAnalyzer *) analyzer;
- (LCAnalyzer *) analyzer;
/** LCDirectory */
- (id <LCDirectory>) directory;
@end

#endif /*  __LuceneKit_Index_Manager__ */
