#include "LCIndexManager.h"
#include "LCRAMDirectory.h"
#include "LCFSDirectory.h"
#include "LCSimpleAnalyzer.h"
#include "GNUstep.h"

//static LCIndexManager *sharedInstance;

@implementation LCIndexManager

/** Check whether an index is existed at path */
+ (BOOL) indexExistsAtPath: (NSString *) path
{
	return [LCIndexReader indexExistsAtPath: path];
}

	/** Initiate an index data in memory */
- (id) init
{
	LCRAMDirectory *d = AUTORELEASE([[LCRAMDirectory alloc] init]);
	LCSimpleAnalyzer *a = AUTORELEASE([[LCSimpleAnalyzer alloc] init]);
	return [self initWithDirectory: d analyzer: a create: YES];
}

	/** Initiate an index data at path.
	* (1) If create is YES and path doesn't exist, a new index data (directory) will be created.
	* (2) If create is NO and paht doesn't exist, it will return nil.
	* (3) If create is YES and path exists, the path will be removed and new index will be created.
	* (4) If create is NO, path exists and is indeed an index data, it will used.
	* (5) If create is NO, path exists and is not an index data, it will return nil;
	*/
- (id) initWithPath: (NSString *) path create: (BOOL) c
{
	/* Check path */
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir;
	if (c == YES)
	{
		if ([manager fileExistsAtPath: path isDirectory: &isDir]) {
			/* (3), remove path */
			[manager removeFileAtPath: path handler: nil];
		}
	}
	else
	{
		if ([manager fileExistsAtPath: path isDirectory: &isDir]) {
			if (isDir && [LCIndexManager indexExistsAtPath: path]) { /* (4) */ }
			else { return nil; /* (5) */ }
		} else {
			/* (2) */
			return nil;
		}
	}
	/* (1), (3) */
	return [self initWithDirectory: [LCFSDirectory directoryAtPath: path create: c]
						  analyzer: AUTORELEASE([[LCSimpleAnalyzer alloc] init])
							create: c];
}

	/** Use Lucene LCDirectory as virtual file system */
- (id) initWithDirectory: (id <LCDirectory>) d create: (BOOL) c
{
	importers = [[NSMutableArray alloc] init];
	paths = [[NSMutableArray alloc] init];
	pairs = [[NSMutableDictionary alloc] init];
	return [self initWithDirectory: d
						  analyzer: AUTORELEASE([[LCSimpleAnalyzer alloc] init])
							create: c];
}

	/** Add path for indexing.
	* This is not stored in index, therefore, for each new LCIndexManager,
	* it must be set before use LCIndexManager.
	* Otherwise, nothing will be indexed.
	* If path is a directory, it will index everything within this directory and its subdirectory.
	*/
- (void) addIndexPath: (NSString *) path
{
	[paths addObject: path];
}

	/** Set indexPaths */
- (void) setIndexPaths: (NSArray *) p
{
	[paths setArray: p];
}

	/** return indexPaths */
- (NSArray *) indexPaths
{
	return paths;
}

	/** Add importer for indexing.
	* Each file (item) in path will be indexed by each importer.
	* If two importers use the same file type,
	* each file will be indexed twice.
	* It is the responsibility of importer to know which type of file it should handle.
	*/
- (void) addImporter: (id <LCImporter>) importer
{
	[importers addObject: importer];
}

- (void) setImporters: (NSArray *) i
{
	[importers setArray: i];
}

- (NSArray *) importers
{
	return importers;
}

	/** Specify importers for a given path.
	* This override the general rules of indexing above.
	* Only the specified importers will be used for path and its subdirectory (if sub is YES).
	* If importers is nil, path will not be indexed.
	*/
- (void) setIndexPath: (NSString *) path importers: (NSArray *) i includeSubpaths: (BOOL) sub
{
	/* Internally, appending '+' as prefix for path including subdirectory, and '-' for not requiring */
	NSString *new;
	if (sub)
		new = [NSString stringWithFormat: @"+%@", path];
	else
		new = [NSString stringWithFormat: @"-%@", path];
	[pairs setObject: i forKey: new];
}

	/** index everything under -indexPaths.
	* It search all the existed document under -indexPaths, remove them, and add them back.
			   * Warn: it cost a lot. It do search and delete, add index if necessary.
	*/
- (void) indexAllFiles
{
}

	/** index new.
	* It compare the value of updateAttributes to determine whether a file should be indexed.
	* Warn: it cost a lot. It do search, compare and delete, add, index if necessary.
	*/
- (void) indexUpdatedFiles
{
}
	/** Index one file
	* This should be used most commonly within any application while an file (item) changed.
	* It is basically a combination of -setIndexPaths: and -indexAll.
	* Since there is only one file at a time, the cost is less. 
	*/
- (void) indexAtPath: (NSString *) path
{
}

	/** Index one file with importer
	*/
- (void) indexAtPath: (NSString *) path importer: (id <LCImporter>) importer
{
}

	/** Remove the document at path.
	* It do search, delete.
	*/
- (void) removeMetadataAtPath: (NSString *) path
{
}

	/* Search */
	/** Return search result based on query.
	* Return an array of values at keyAttribute.
	*/
- (NSArray *) searchWithString: (NSString *) query
{
	return nil;
}

	/** Return search result based on query. */
- (NSArray *) searchWithQuery: (LCQuery *) query
{
	return nil;
}

	/* Advanced funcation */
	/** Return indexReader.
	* IndexReader and IndexWriter cannot exist at the same time.
	* When one is called, the other is closed by IndexManager.
	* Do not close indexReader or indexWriter on you own.
	* But when you have any of them, do not use the other one because it is closed.
	*/
- (LCIndexReader *) indexReader { return indexReader; }
	/** Return indexWriter. See -indexReader */
- (LCIndexWriter *) indexWriter { return indexWriter; }
	/** Return LCDocument at path */
- (LCDocument *) documentAtPath: (NSString *) path
{
	return nil;
}

	/** default analyzer */
- (void) setAnalyzer: (LCAnalyzer *) a { ASSIGN(analyzer, a); }
- (LCAnalyzer *) analyzer { return analyzer; }
	/** LCDirectory */
- (id <LCDirectory>) directory { return directory; }

@end
