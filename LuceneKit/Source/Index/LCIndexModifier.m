#include "LCIndexModifier.h"
#include "GNUstep.h"

@interface LCIndexModifier (LCPrivate)
- (void) initializeDirectory: (id <LCDirectory>) d
	analyzer: (LCAnalyzer *) a
	create: (BOOL) c;
@end

@implementation LCIndexModifier

- (id) init
{
	self = [super init];
	indexWriter = nil;
	indexReader = nil;
	directory = nil;
	analyzer = nil;
	open = NO;

	useCompoundFile = YES;
	maxBufferedDocs = DEFAULT_MIN_MERGE_DOCS;
	maxFieldLength = DEFAULT_MAX_FIELD_LENGTH;
	mergeFactor = DEFAULT_MERGE_FACTOR;
	
	return self;
}

- (id) initWithDirectory: (id <LCDirectory>) d
		analyzer: (LCAnalyzer *) a
		create: (BOOL) c
{
	self = [self init];
	[self initializeDirectory: d analyzer: a create: c];
	return self;
}

#if 0
  public IndexModifier(String dirName, Analyzer analyzer, boolean create) throws IOException {
    Directory dir = FSDirectory.getDirectory(dirName, create);
    init(dir, analyzer, create);
  }
  
  public IndexModifier(File file, Analyzer analyzer, boolean create) throws IOException {
    Directory dir = FSDirectory.getDirectory(file, create);
    init(dir, analyzer, create);
  }
#endif

- (void) initializeDirectory: (id <LCDirectory>) d
	analyzer: (LCAnalyzer *) a
	create: (BOOL) c
{
	ASSIGN(directory, d);
	ASSIGN(analyzer, a);
	ASSIGN(indexWriter, AUTORELEASE([[LCIndexWriter alloc] initWithDirectory: d analyzer: a create: c]));
	open = YES;
}

- (void) dealloc
{
  DESTROY(directory);
  DESTROY(analyzer);
  DESTROY(indexWriter);
  DESTROY(indexReader);
  [super dealloc];
}

- (void) assureOpen
{
	if (!open) { NSLog(@"Index is closed"); }
}

- (void) createIndexWriter
{
	if (indexWriter == nil) {
		if (indexReader != nil) {
			[indexReader close];
			DESTROY(indexReader);
		}
		ASSIGN(indexWriter, AUTORELEASE([[LCIndexWriter alloc] initWithDirectory: directory analyzer: analyzer create: NO]));
		[indexWriter setUseCompoundFile: useCompoundFile];
		[indexWriter setMaxBufferedDocuments: maxBufferedDocs];
		[indexWriter setMaxFieldLength: maxFieldLength];
		[indexWriter setMergeFactor: mergeFactor];
    	}
}


- (void) createIndexReader
{
	if (indexReader == nil) {
		if (indexWriter != nil) {
			[indexWriter close];
			DESTROY(indexWriter);
		}
	ASSIGN(indexReader, [LCIndexReader openDirectory: directory]);
	}
}

- (void) flush
{
	[self assureOpen];
	if (indexWriter != nil) {
		[indexWriter close];
		DESTROY(indexWriter);
		[self createIndexWriter];
	} else {
		[indexReader close];
		DESTROY(indexReader);
		[self createIndexReader];
	}
}

- (void) addDocument: (LCDocument *) doc
	analyzer: (LCAnalyzer *) docAnalyzer
{
	[self assureOpen];
	[self createIndexWriter];
	if (docAnalyzer != nil)
		[indexWriter addDocument: doc analyzer: docAnalyzer];
	else
		[indexWriter addDocument: doc];
}

- (void) addDocument: (LCDocument *) doc
{
	[self addDocument: doc analyzer: nil];
}

- (int) deleteTerm: (LCTerm *) term
{
	[self assureOpen];
	[self createIndexReader];
	return [indexReader deleteTerm: term];
}

- (void) deleteDocument: (int) docNum
{
	[self assureOpen];
	[self createIndexReader];
	[indexReader deleteDocument: docNum];
}
  
- (int) numberOfDocuments
{
	[self assureOpen];
	if (indexWriter != nil) {
		return [indexWriter numberOfDocuments];
	} else {
		return [indexReader numberOfDocuments];
	}
}

- (void) optimize
{
	[self assureOpen];
	[self createIndexWriter];
	[indexWriter optimize];
}

- (void) setUseCompoundFile: (BOOL) use
{
	[self assureOpen];
	if (indexWriter != nil) {
		[indexWriter setUseCompoundFile: use];
	}
	useCompoundFile = use;
}

- (BOOL) useCompoundFile
{
	[self assureOpen];
	[self createIndexWriter];
	return [indexWriter useCompoundFile];
}

- (void) setMaxFieldLength: (int) max
{
	[self assureOpen];
	if (indexWriter != nil) {
		[indexWriter setMaxFieldLength: max];
	}
	maxFieldLength = max;
}

- (int) maxFieldLength
{
	[self assureOpen];
	[self createIndexWriter];
	return [indexWriter maxFieldLength];
}
  
- (void) setMaxBufferedDocuments: (int) max
{
	[self assureOpen];
	if (indexWriter != nil) {
		[indexWriter setMaxBufferedDocuments: max];
	}
	maxBufferedDocs = max;
}

- (int) maxBufferedDocuments
{
	[self assureOpen];
	[self createIndexWriter];
	return [indexWriter maxBufferedDocuments];
}

- (void) setMergeFactor: (int) factor
{
	[self assureOpen];
	if (indexWriter != nil) {
		[indexWriter setMergeFactor: factor];
	}
	mergeFactor = factor;
}

- (int) mergeFactor
{
	[self assureOpen];
	[self createIndexWriter];
	return [indexWriter mergeFactor];
}

- (void) close
{
	if (!open) NSLog(@"Index is closed already");
	if (indexWriter != nil) {
		[indexWriter close];
		DESTROY(indexWriter);
	} else {
		[indexReader close];
		DESTROY(indexReader);
	}
	open = NO;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"Index@%@", directory];
}
  
@end
