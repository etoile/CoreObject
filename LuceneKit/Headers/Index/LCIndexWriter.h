#ifndef __LUCENE_INDEX_INDEX_WRITER__
#define __LUCENE_INDEX_INDEX_WRITER__

#include <Foundation/Foundation.h>
#include "LCSimilarity.h"
#include "LCAnalyzer.h"
#include "LCDocument.h"
#include "LCDirectory.h"

#define WRITE_LOCK_TIMEOUT 1000
#define COMMIT_LOCK_TIMEOUT 10000
#define WRITE_LOCK_NAME @"write.lock"
#define COMMIT_LOCK_NAME @"commit.lock"
#define DEFAULT_MERGE_FACTOR 10
#define DEFAULT_MIN_MERGE_DOCS 10
#define DEFAULT_MAX_MERGE_DOCS (((unsigned int)-1)/2-1)
#define DEFAULT_MAX_FIELD_LENGTH 10000
#define DEFAULT_TERM_INDEX_INTERVAL 128

@class LCSegmentInfos;

@interface LCIndexWriter: NSObject
{
	id <LCDirectory> directory;  // where this index resides
	LCAnalyzer *analyzer;    // how to analyze text
	LCSimilarity *similarity; // how to normalize
	LCSegmentInfos *segmentInfos; // the segments
	id <LCDirectory> ramDirectory; // for temp segs
	
	//Lock writeLock;
	int termIndexInterval;
	
	/** Use compound file setting. Defaults to true, minimizing the number of
		* files used.  Setting this to false may improve indexing performance, but
		* may also cause file handle problems.
		*/
	BOOL useCompoundFile;
	BOOL closeDir;
	
    /** Determines the largest number of documents ever merged by addDocument().
		* Small values (e.g., less than 10,000) are best for interactive indexing,
		* as this limits the length of pauses while indexing to a few seconds.
		* Larger values are best for batched indexing and speedier searches.
		*
		* <p>The default value is {@link Integer#MAX_VALUE}.
	* @deprecated use {@link #setMaxMergeDocuments} instead
		*/
    int maxMergeDocs;
	
	/** Determines how often segment indices are merged by addDocument().  With
		* smaller values, less RAM is used while indexing, and searches on
		* unoptimized indices are faster, but indexing speed is slower.  With larger
		* values, more RAM is used during indexing, and while searches on unoptimized
		* indices are slower, indexing is faster.  Thus larger values (> 10) are best
		* for batch index creation, and smaller values (< 10) for indices that are
		* interactively maintained.
		*
		* <p>This must never be less than 2.  The default value is 10.
	* @deprecated use {@link #setMergeFactor} instead
		*/
	int mergeFactor;
	
	/**
		* The maximum number of terms that will be indexed for a single field in a
	 * document.  This limits the amount of memory required for indexing, so that
	 * collections with very large files will not crash the indexing process by
	 * running out of memory.<p/>
	 * Note that this effectively truncates large documents, excluding from the
	 * index terms that occur further in the document.  If you know your source
	 * documents are large, be sure to set this value high enough to accomodate
	 * the expected size.  If you set it to Integer.MAX_VALUE, then the only limit
	 * is your memory, but you should anticipate an OutOfMemoryError.<p/>
	 * By default, no more than 10,000 terms will be indexed for a field.
	 * 
	 * @deprecated use {@link #setMaxFieldLength} instead
	 */
	int maxFieldLength;
	
	/** Determines the minimal number of documents required before the buffered
		* in-memory documents are merging and a new Segment is created.
		* Since Documents are merged in a {@link org.apache.lucene.store.RAMDirectory},
		* large value gives faster indexing.  At the same time, mergeFactor limits
		* the number of files open in a FSDirectory.
		*
		* <p> The default value is 10.
	* @deprecated use {@link #setMaxBufferedDocuments} instead
		*/
	int minMergeDocs;
	
	
}

- (BOOL) useCompoundFile;
- (void) setUseCompoundFile: (BOOL) value;
- (void) setSimilarity: (LCSimilarity *) similarity;
- (LCSimilarity *) similarity;
- (void) setTermIndexInterval: (int) interval;
- (int) termIndexInterval;
- (id) initWithPath: (NSString *) path 
		   analyzer: (LCAnalyzer *) a
			 create: (BOOL) create;
- (id) initWithDirectory: (id <LCDirectory>) dir 
				analyzer: (LCAnalyzer *) a
				  create: (BOOL) create;
- (void) setMaxMergeDocuments: (int) maxMergeDocs;
- (int) maxMergeDocuments;
- (void) setMaxFieldLength: (int) maxFieldLength;
- (int) maxFieldLength;
- (void) setMaxBufferedDocuments: (int) maxBufferedDocs;
- (int) maxBufferedDocuments;
- (void) setMergeFactor: (int) mergeFactor;
- (int) mergeFactor;
- (void) close;
- (id <LCDirectory>) directory;
- (LCAnalyzer *) analyzer;
- (int) numberOfDocuments;
- (void) addDocument: (LCDocument *) doc;
- (void) addDocument: (LCDocument *) doc
			analyzer: (LCAnalyzer *) analyzer;
- (int) numberOfSegments;
- (void) optimize;
- (void) addIndexesWithDirectories: (NSArray *) dirs;
- (void) addIndexesWithReaders: (NSArray *) readers;

@end

#endif /* __LUCENE_INDEX_INDEX_WRITER__ */
