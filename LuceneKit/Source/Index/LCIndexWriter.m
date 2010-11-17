#include "LCIndexWriter.h"
#include "LCSegmentInfos.h"
#include "LCSegmentReader.h"
#include "LCSegmentMerger.h"
#include "LCDocumentWriter.h"
#include "LCRAMDirectory.h"
#include "LCFSDirectory.h"
#include "GNUstep.h"

/**
An IndexWriter creates and maintains an index.
 
 The third argument to the 
 <a href="#IndexWriter(org.apache.lucene.store.Directory, org.apache.lucene.analysis.Analyzer, boolean)"><b>constructor</b></a>
 determines whether a new index is created, or whether an existing index is
 opened for the addition of new documents.
 
 In either case, documents are added with the <a
 href="#addDocument(org.apache.lucene.document.Document)"><b>addDocument</b></a> method.  
 When finished adding documents, <a href="#close()"><b>close</b></a> should be called.
 
 If an index will not have more documents added for a while and optimal search
 performance is desired, then the <a href="#optimize()"><b>optimize</b></a>
 method should be called before the index is closed.
 */

@interface LCIndexWriter (LCPrivate)
- (id) initWithDirectory: (id <LCDirectory>) dir 
				analyzer: (LCAnalyzer *) a
				  create: (BOOL) create
				   close: (BOOL) closeDir;
- (NSString *) newSegmentName;
- (void) flushRamSegments;
- (void) maybeMergeSegments;
- (void) mergeSegments: (int) minSegment;
- (void) mergeSegments: (int) minSegment size: (int) end;
- (void) deleteSegments: (NSArray *) segments;
- (void) deleteFiles: (NSArray *) files;
- (void) deleteFiles: (NSArray *) files directory: (id <LCDirectory>) dir;
- (void) deleteFiles: (NSArray *) files deletable: (NSMutableArray *) deletable;
- (NSArray *) readDeleteableFiles;
- (void) writeDeleteableFiles: (NSArray *) files;

@end

@implementation LCIndexWriter

- (id) init
{
	self = [super init];
	ASSIGN(similarity, [LCSimilarity defaultSimilarity]);
	ASSIGN(segmentInfos, AUTORELEASE([[LCSegmentInfos alloc] init]));
	ASSIGN(ramDirectory, AUTORELEASE([[LCRAMDirectory alloc] init]));
	termIndexInterval = DEFAULT_TERM_INDEX_INTERVAL;
	
	useCompoundFile = YES;
	
	maxMergeDocs = DEFAULT_MAX_MERGE_DOCS;
	
	mergeFactor = DEFAULT_MERGE_FACTOR;
	
	maxFieldLength = DEFAULT_MAX_FIELD_LENGTH;
	
	minMergeDocs = DEFAULT_MIN_MERGE_DOCS;
	
	return self;
}

- (BOOL) useCompoundFile 
{
	return useCompoundFile;
}

/** Setting to turn on usage of a compound file. When on, multiple files
*  for each segment are merged into a single file once the segment creation
*  is finished. This is done regardless of what directory is in use.
*/
- (void) setUseCompoundFile: (BOOL) value
{
	useCompoundFile = value;
}

/** Expert: Set the Similarity implementation used by this IndexWriter.
*
* @see Similarity#setDefault(Similarity)
*/
- (void) setSimilarity: (LCSimilarity *) sim
{
	ASSIGN(similarity,sim);
}

/** Expert: Return the Similarity implementation used by this IndexWriter.
*
* <p>This defaults to the current value of {@link Similarity#getDefault()}.
*/
- (LCSimilarity *) similarity
{
	return similarity;
}

/** Expert: Set the interval between indexed terms.  Large values cause less
* memory to be used by IndexReader, but slow random-access to terms.  Small
* values cause more memory to be used by an IndexReader, and speed
* random-access to terms.  In particular,
* <code>numUniqueTerms/interval</code> terms are read into memory by an
* IndexReader, and, on average, <code>interval/2</code> terms must be
* scanned for each random term access.
*
* @see #DEFAULT_TERM_INDEX_INTERVAL
*/
- (void) setTermIndexInterval: (int) val
{
	termIndexInterval = val;
}

/** Expert: Return the interval between indexed terms.
*
* @see #setTermIndexInterval(int)
*/
- (int) termIndexInterval
{
	return termIndexInterval;
} 

/**
* Constructs an IndexWriter for the index in <code>path</code>.
 * Text will be analyzed with <code>a</code>.  If <code>create</code>
 * is true, then a new, empty index will be created in
 * <code>path</code>, replacing the index already there, if any.
 *
 * @param path the path to the index directory
 * @param a the analyzer to use
 * @param create <code>true</code> to create the index or overwrite
 *  the existing one; <code>false</code> to append to the existing
 *  index
 * @throws IOException if the directory cannot be read/written to, or
 *  if it does not exist, and <code>create</code> is
 *  <code>false</code>
 */
- (id) initWithPath: (NSString *) path
		   analyzer: (LCAnalyzer *) a
			 create: (BOOL) create
{
	return [self initWithDirectory: [LCFSDirectory directoryAtPath: path
														 create: create]
						  analyzer: a create: create close: YES];
}

/**
* Constructs an IndexWriter for the index in <code>d</code>.
 * Text will be analyzed with <code>a</code>.  If <code>create</code>
 * is true, then a new, empty index will be created in
 * <code>d</code>, replacing the index already there, if any.
 *
 * @param d the index directory
 * @param a the analyzer to use
 * @param create <code>true</code> to create the index or overwrite
 *  the existing one; <code>false</code> to append to the existing
 *  index
 * @throws IOException if the directory cannot be read/written to, or
 *  if it does not exist, and <code>create</code> is
 *  <code>false</code>
 */
- (id) initWithDirectory: (id <LCDirectory>) dir
				analyzer: (LCAnalyzer *) a
				  create: (BOOL) create
{
	return [self initWithDirectory: dir
						  analyzer: a
							create: create
							 close: NO];
}

- (id) initWithDirectory: (id <LCDirectory>) dir
				analyzer: (LCAnalyzer *) a
				  create: (BOOL) create
				   close: (BOOL) close
{
	self = [self init];
	closeDir = close;
	ASSIGN(directory, dir);
	ASSIGN(analyzer, a);
	
#if 0
	Lock writeLock = directory.makeLock(IndexWriter.WRITE_LOCK_NAME);
	if (!writeLock.obtain(WRITE_LOCK_TIMEOUT)) // obtain write lock
        throw new IOException("Index locked for write: " + writeLock);
	this.writeLock = writeLock;                   // save it
#endif
	
#if 0
	synchronized (directory) {        // in- & inter-process sync
        new Lock.With(directory.makeLock(IndexWriter.COMMIT_LOCK_NAME), COMMIT_LOCK_TIMEOUT) {
            public Object doBody() throws IOException {
#endif
				if (create)
					[segmentInfos writeToDirectory: directory];
				else
					[segmentInfos readFromDirectory: directory];
				//return null;
#if 0
            }
		}.run();
	}
#endif
	return self;
}

/** Release the write lock, if needed. */
- (void) dealloc
{
#if 0
    if (writeLock != null) {
		writeLock.release();                        // release write lock
		writeLock = null;
    }
#endif
	DESTROY(analyzer);
	DESTROY(similarity);
	DESTROY(segmentInfos);
	DESTROY(ramDirectory);
	DESTROY(directory);
	DESTROY(segmentInfos);
	[super dealloc];
}
/** Determines the largest number of documents ever merged by addDocument().
* Small values (e.g., less than 10,000) are best for interactive indexing,
* as this limits the length of pauses while indexing to a few seconds.
* Larger values are best for batched indexing and speedier searches.
*
* <p>The default value is {@link Integer#MAX_VALUE}.
*/
- (void) setMaxMergeDocuments: (int) max
{
	maxMergeDocs = max;
}

/**
* @see #setMaxMergeDocuments
 */
- (int) maxMergeDocuments
{
	return maxMergeDocs;
}

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
 */
- (void) setMaxFieldLength: (int) max
{
	maxFieldLength = max;
}

/**
* @see #setMaxFieldLength
 */
- (int) maxFieldLength
{
	return maxFieldLength;
}

/** Determines the minimal number of documents required before the buffered
* in-memory documents are merging and a new Segment is created.
* Since Documents are merged in a {@link org.apache.lucene.store.RAMDirectory},
* large value gives faster indexing.  At the same time, mergeFactor limits
* the number of files open in a FSDirectory.
*
* <p> The default value is 10.
* 
* @throws IllegalArgumentException if maxBufferedDocs is smaller than 1 
*/
- (void) setMaxBufferedDocuments: (int) max
{
	if (max < 2)
	{
		NSLog(@"maxBufferedDocs must at least be 2");
    		minMergeDocs = 2;
	}
	else
	{
		minMergeDocs = max;
	}
}

/**
* @see #setMaxBufferedDocuments
 */
- (int) maxBufferedDocuments
{
	return minMergeDocs;
}

/** Determines how often segment indices are merged by addDocument().  With
* smaller values, less RAM is used while indexing, and searches on
* unoptimized indices are faster, but indexing speed is slower.  With larger
* values, more RAM is used during indexing, and while searches on unoptimized
* indices are slower, indexing is faster.  Thus larger values (> 10) are best
* for batch index creation, and smaller values (< 10) for indices that are
* interactively maintained.
*
* <p>This must never be less than 2.  The default value is 10.
*/
- (void) setMergeFactor: (int) factor
{
    if (factor < 2)
    {
		NSLog(@"mergeFactor cannot be less than 2");
    }
    mergeFactor = factor;
}

/**
* @see #setMergeFactor
 */
- (int) mergeFactor
{
	return mergeFactor;
}

/** Flushes all changes to an index and closes all associated files. */
- (void) close
{
	[self flushRamSegments];
	[ramDirectory close];
#if 0
    if (writeLock != null) {
		writeLock.release();                          // release write lock
		writeLock = null;
    }
#endif
	if(closeDir)
		[directory close];
}

/** Returns the Directory used by this index. */
- (id <LCDirectory>) directory;
{
	return directory;
}

/** Returns the analyzer used by this index. */
- (LCAnalyzer *) analyzer
{
	return analyzer;
}


/** Returns the number of documents currently in this index. */
- (int) numberOfDocuments
{
	int i, count = 0;
	LCSegmentInfo *si;
	for (i = 0; i < [segmentInfos numberOfSegments]; i++) {
		si = [segmentInfos segmentInfoAtIndex: i];
		count += [si numberOfDocuments];
	}
	return count;
}

/**
* Adds a document to this index.  If the document contains more than
 * {@link #maxFieldLength} terms for a given field, the remainder are
 * discarded.
 */
- (void) addDocument: (LCDocument *) doc
{
	[self addDocument: doc analyzer: analyzer];
}

/**
* Adds a document to this index, using the provided analyzer instead of the
 * value of {@link #getAnalyzer()}.  If the document contains more than
 * {@link #maxFieldLength} terms for a given field, the remainder are
 * discarded.
 */
- (void) addDocument: (LCDocument *) doc
			analyzer: (LCAnalyzer *) a
{
//NSLog(@"addDocument %@ analyzer %@", doc, a);
	LCDocumentWriter *dw = [[LCDocumentWriter alloc] initWithDirectory: ramDirectory
															  analyzer: a indexWriter: self];
    //[dw setInfoStream: infoStream];
	NSString *segmentName = [self newSegmentName];
	[dw addDocument: segmentName document: doc];
	DESTROY(dw);
	//    synchronized (this) {
	[segmentInfos addSegmentInfo: AUTORELEASE([[LCSegmentInfo alloc] initWithName: segmentName numberOfDocuments: 1 directory: ramDirectory])];
	[self maybeMergeSegments];
	//    }
}

- (int) numberOfSegments
{
	return [segmentInfos counter];
}

- (NSString *) newSegmentName
{
	return [NSString stringWithFormat: @"_%d", [segmentInfos increaseCounter]];
	//    return "_" + Integer.toString(segmentInfos.counter++, Character.MAX_RADIX);
}

/** Merges all segments together into a single segment, optimizing an index
for search. */
- (void) optimize
{
	CREATE_AUTORELEASE_POOL(pool);
	[self flushRamSegments];
	while ([segmentInfos numberOfSegments] > 1 ||
		   ([segmentInfos numberOfSegments] == 1 &&
			([LCSegmentReader hasDeletions: [segmentInfos segmentInfoAtIndex: 0]] ||
			 [[segmentInfos segmentInfoAtIndex: 0] directory] != directory ||
			 (useCompoundFile &&
			  (![LCSegmentReader usesCompoundFile: [segmentInfos segmentInfoAtIndex: 0]] ||
			   [LCSegmentReader hasSeparateNorms: [segmentInfos segmentInfoAtIndex: 0]]))))) {
		int minSegment = [segmentInfos numberOfSegments] - mergeFactor;
		[self mergeSegments: ((minSegment < 0) ? 0 : minSegment)];
	}
	DESTROY(pool);
}

/** Merges all segments from an array of indexes into this index.
*
* <p>This may be used to parallelize batch indexing.  A large document
* collection can be broken into sub-collections.  Each sub-collection can be
* indexed in parallel, on a different thread, process or machine.  The
* complete index can then be created by merging sub-collection indexes
* with this method.
*
* <p>After this completes, the index is optimized. */
- (void) addIndexesWithDirectories: (NSArray *) dirs
{
	[self optimize];	  // start with zero or 1 seg
	int start = [segmentInfos numberOfSegments];
	int i;
	for (i = 0; i < [dirs count]; i++) {
		LCSegmentInfos *sis = [[LCSegmentInfos alloc] init];  // read infos from dir
		[sis readFromDirectory: [dirs objectAtIndex: i]];
		int j;
		for (j = 0; j < [sis numberOfSegments]; j++) {
			[segmentInfos addSegmentInfo: [sis segmentInfoAtIndex: j]]; // add each info
		}
		DESTROY(sis);
	}
	
	while ([segmentInfos numberOfSegments] > start + mergeFactor)
	{
		int base, end;
		for (base = start; base < [segmentInfos numberOfSegments]; base++)
		{
			end = ([segmentInfos numberOfSegments] < (base+mergeFactor)) ? [segmentInfos numberOfSegments] : (base+mergeFactor);
			if ((end - base) > 1)
				[self mergeSegments: base size: end];
		}
	}

	[self optimize];
}

/** Merges the provided indexes into this index.
* <p>After this completes, the index is optimized. </p>
* <p>The provided IndexReaders are not closed.</p>
*/
- (void) addIndexesWithReaders: (NSArray *) readers
{
	[self optimize]; // start with zero or 1 seg
	
	NSString *mergedName = [self newSegmentName];
	LCSegmentMerger *merger = [[LCSegmentMerger alloc] initWithIndexWriter:self
																	  name: mergedName];
	NSMutableArray *segmentsToDelete = [[NSMutableArray alloc] init];
	LCIndexReader *sReader = nil;
	if ([segmentInfos numberOfSegments] == 1){ // add existing index, if any
		sReader = [LCSegmentReader segmentReaderWithInfo: [segmentInfos segmentInfoAtIndex: 0]];
		[merger addIndexReader: sReader];
		[segmentsToDelete addObject: sReader];  // queue segment for deletion
	}
	
	int i;
	for (i = 0; i < [readers count]; i++)      // add new indexes
		[merger addIndexReader: [readers objectAtIndex: i]];
	
	int docCount = [merger merge];                // merge 'em
	
	NSRange r = NSMakeRange(0, [segmentInfos numberOfSegments]);
	[segmentInfos removeSegmentsInRange: r];  // pop old infos & add new
	[segmentInfos addSegmentInfo: AUTORELEASE([[LCSegmentInfo alloc] initWithName: mergedName
																numberOfDocuments: docCount directory: directory])];
    
	if(sReader != nil)
		[sReader close];
	
#if 0
    synchronized (directory) {			  // in- & inter-process sync
		new Lock.With(directory.makeLock(COMMIT_LOCK_NAME), COMMIT_LOCK_TIMEOUT) {
			public Object doBody() throws IOException {
#endif
				[segmentInfos writeToDirectory: directory]; // commit changes
				[self deleteSegments: segmentsToDelete]; // delete now-unused segments
#if 0
				return null;
			}
		}.run();
    }
#endif
    
	if (useCompoundFile) {
		NSArray *filesToDelete = [merger createCompoundFile: [mergedName stringByAppendingPathExtension: @"tmp"]];
#if 0
		synchronized (directory) { // in- & inter-process sync
			new Lock.With(directory.makeLock(COMMIT_LOCK_NAME), COMMIT_LOCK_TIMEOUT) {
				public Object doBody() throws IOException {
#endif
					// make compound file visible for SegmentReaders
					[directory renameFile: [mergedName stringByAppendingPathExtension: @"tmp"]
									   to: [mergedName stringByAppendingPathExtension: @"cfs"]];
					// delete now unused files of segment 
					[self deleteFiles: filesToDelete];
#if 0
					return null;
				}
			}.run();
		}
#endif
	}
	DESTROY(segmentsToDelete);
	DESTROY(merger);
}

/** Merges all RAM-resident segments. */
- (void) flushRamSegments
{
	int minSegment = [segmentInfos numberOfSegments]-1;
	int docCount = 0;
	while (minSegment >= 0 &&
		   ([[segmentInfos segmentInfoAtIndex: minSegment] directory] == ramDirectory)) {
		docCount += [[segmentInfos segmentInfoAtIndex: minSegment] numberOfDocuments];
		minSegment--;
	}
	if (minSegment < 0 ||			  // add one FS segment?
		(docCount + [[segmentInfos segmentInfoAtIndex: minSegment] numberOfDocuments]) > mergeFactor ||
		!([[segmentInfos segmentInfoAtIndex: [segmentInfos numberOfSegments]-1] directory] == ramDirectory))
		minSegment++;
	if (minSegment >= [segmentInfos numberOfSegments])
		return;					  // none to merge
	[self mergeSegments: minSegment];
}

/** Incremental segment merger.  */
- (void) maybeMergeSegments
{
	long targetMergeDocs = minMergeDocs;
	while (targetMergeDocs <= maxMergeDocs) {
		// find segments smaller than current target size
		int minSegment = [segmentInfos numberOfSegments];
		int mergeDocs = 0;
		while (--minSegment >= 0) {
			LCSegmentInfo *si = [segmentInfos segmentInfoAtIndex: minSegment];
			if ([si numberOfDocuments] >= targetMergeDocs)
				break;
			mergeDocs += [si numberOfDocuments];
		}
		
		if (mergeDocs >= targetMergeDocs)		  // found a merge to do
		{
			[self mergeSegments: minSegment+1];
		}
		else
		{
			break;
		}
		targetMergeDocs *= mergeFactor;		  // increase target size
	}
}

/** Pops segments off of segmentInfos stack down to minSegment, merges them,
and pushes the merged index onto the top of the segmentInfos stack. */
- (void) mergeSegments: (int) minSegment
{
	[self mergeSegments: minSegment size: [segmentInfos numberOfSegments]];
}

- (void) mergeSegments: (int) minSegment size: (int) end
{
	NSString *mergedName = [self newSegmentName];
	//    if (infoStream != nil) infoStream.print("merging segments");
	LCSegmentMerger *merger = [[LCSegmentMerger alloc] initWithIndexWriter: self
																	  name: mergedName];
	
	NSMutableArray *segmentsToDelete = [[NSMutableArray alloc] init];
	int i;
	LCSegmentInfo *si = nil;
	LCIndexReader *reader = nil;
	for (i = minSegment; i < end; i++) {
		
		si = [segmentInfos segmentInfoAtIndex: i];
		reader = [LCSegmentReader segmentReaderWithInfo: si];
		[merger addIndexReader: reader];
		if (([reader directory] == directory) || // if we own the directory
			([reader directory] == ramDirectory))
			[segmentsToDelete addObject: reader];   // queue segment for deletion
	}
	int mergedDocCount = [merger merge];
	
	NSRange r = NSMakeRange(minSegment+1, end-minSegment-1);
	[segmentInfos removeSegmentsInRange: r]; // pop old infos & add new

	[segmentInfos setSegmentInfo: AUTORELEASE([[LCSegmentInfo alloc] initWithName: mergedName
																numberOfDocuments: mergedDocCount directory: directory])
		      atIndex: minSegment];
    // close readers before we attempt to delete now-obsolete segments
	[merger closeReaders];
#if 0
    synchronized (directory) {                 // in- & inter-process sync
		new Lock.With(directory.makeLock(COMMIT_LOCK_NAME), COMMIT_LOCK_TIMEOUT) {
			public Object doBody() throws IOException {
#endif
				[segmentInfos writeToDirectory: directory];     // commit before deleting
				[self  deleteSegments: segmentsToDelete];  // delete now-unused segments
#if 0
				return null;
			}
        }.run();
    }
#endif
    
	if (useCompoundFile) {
		NSMutableArray *filesToDelete = [[NSMutableArray alloc] initWithArray: [merger createCompoundFile: [mergedName stringByAppendingPathExtension: @"tmp"]]];
		
#if 0
		synchronized (directory) { // in- & inter-process sync
			new Lock.With(directory.makeLock(COMMIT_LOCK_NAME), COMMIT_LOCK_TIMEOUT) {
				public Object doBody() throws IOException {
#endif
					// make compound file visible for SegmentReaders
					[directory renameFile: [mergedName stringByAppendingPathExtension: @"tmp"]
									   to: [mergedName stringByAppendingPathExtension: @"cfs"]];
					// delete now unused files of segment 
					[self deleteFiles: filesToDelete];
#if 0
					return null;
				}
			}.run();
		}
#endif
		DESTROY(filesToDelete);
	}
	DESTROY(segmentsToDelete);
	DESTROY(merger);
}

/*
 * Some operating systems (e.g. Windows) don't permit a file to be deleted
 * while it is opened for read (e.g. by another process or thread). So we
 * assume that when a delete fails it is because the file is open in another
 * process, and queue the file for subsequent deletion.
 */
- (void) deleteSegments: (NSArray *) segments
{
	NSMutableArray *deletable = [[NSMutableArray alloc] init];
	
	[self deleteFiles: [self readDeleteableFiles]
			deletable: deletable]; // try to delete deleteable
	
	int i;
	for (i = 0; i < [segments count]; i++) {
		LCSegmentReader *reader = (LCSegmentReader *)[segments objectAtIndex: i];
		
		if ([reader directory] == directory) {
			[self deleteFiles: [reader files]
					deletable: deletable];	  // try to delete our files
		} else {
			[self deleteFiles: [reader files]
					directory: [reader directory]];  // delete other files
		}
	}
	
	[self writeDeleteableFiles: deletable]; // note files we can't delete
	DESTROY(deletable);
}

- (void) deleteFiles: (NSArray *) files
{
	NSMutableArray *deletable = [[NSMutableArray alloc] init];
	[self deleteFiles: [self readDeleteableFiles]
			deletable: deletable]; // try to delete deleteable
	[self deleteFiles: files
			deletable: deletable];    // try to delete our files
	[self writeDeleteableFiles: deletable];        // note files we can't delete
	DESTROY(deletable);
}

- (void) deleteFiles: (NSArray *) files directory: (id <LCDirectory>) dir
{
	int i;
	for (i = 0; i < [files count]; i++)
		[directory deleteFile: [files objectAtIndex: i]];
}

- (void) deleteFiles: (NSArray *) files deletable: (NSMutableArray *) deletable
{
	int i;
	BOOL result;
	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
#if 0
		try {
#endif 
			result = [directory deleteFile: file];	  // try to delete each file
			if ([directory fileExists: file] && (result == NO))
			{
				[deletable addObject: file];
			}
#if 0
		} catch (IOException e) {			  // if delete fails
			if (directory.fileExists(file)) {
				if (infoStream != null)
					infoStream.println(e.toString() + "; Will re-try later.");
				deletable.addElement(file);		  // add to deletable
			}
		}
#endif
    }
}

- (NSArray *) readDeleteableFiles
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	if (![directory fileExists: @"deletable"])
		return AUTORELEASE(result);
	
	LCIndexInput *input = [directory openInput: @"deletable"];
	int ii;
	for (ii = [input readInt]; ii > 0; ii--)	  // read file names
		[result addObject: [input readString]];
	[input close];
	return AUTORELEASE(result);
}

- (void) writeDeleteableFiles: (NSArray *) files
{
	LCIndexOutput *output = [directory createOutput: @"deleteable.new"];
	
	[output writeInt: (long)[files count]];
	int i;
	for (i = 0; i < [files count]; i++)
		[output writeString: [files objectAtIndex: i]];
	[output close];
	[directory renameFile: @"deleteable.new"
					   to: @"deletable"];
}

@end
