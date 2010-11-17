#ifndef __LuceneKit_Index_Modifier__
#define __LuceneKit_Index_Modifier__

#include <Foundation/Foundation.h>
#include "LCIndexReader.h"
#include "LCIndexWriter.h"

@interface LCIndexModifier: NSObject
{
	LCIndexReader *indexReader;
	LCIndexWriter *indexWriter;
	id <LCDirectory> directory;
	LCAnalyzer *analyzer;
	BOOL open;
	BOOL useCompoundFile;
	int maxBufferedDocs;
	int maxFieldLength;
	int mergeFactor;
}

- (id) initWithDirectory: (id <LCDirectory>) directory
				analyzer: (LCAnalyzer *) analyzer
				  create: (BOOL) create;
- (void) initializeDirectory: (id <LCDirectory>) directory
				analyzer: (LCAnalyzer *) analyzer
				  create: (BOOL) create;
- (void) flush;
- (void) addDocument: (LCDocument *) doc
			analyzer: (LCAnalyzer *) docAnalyzer;
- (void) addDocument: (LCDocument *) doc;
- (int) deleteTerm: (LCTerm *) term;
- (void) deleteDocument: (int) docNum;
- (int) numberOfDocuments;
- (void) optimize;
- (void) setUseCompoundFile: (BOOL) useCompoundFile;
- (BOOL) useCompoundFile;
- (void) setMaxFieldLength: (int) max;
- (int) maxFieldLength;
- (void) setMaxBufferedDocuments: (int) max;
- (int) maxBufferedDocuments;
- (void) setMergeFactor: (int) factor;
- (int) mergeFactor;
- (void) close;

/* protected */
- (void) assureOpen;
- (void) createIndexWriter;
- (void) createIndexReader;

@end

#endif /*  __LuceneKit_Index_Modifier__ */

