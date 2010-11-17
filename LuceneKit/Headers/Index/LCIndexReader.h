#ifndef __LUCENE_INDEX_INDEX_READER__
#define __LUCENE_INDEX_INDEX_READER__

#include <Foundation/Foundation.h>
#include "LCTermDocs.h"
#include "LCTermFreqVector.h"
#include "LCTermPositions.h"
#include "LCSegmentInfos.h"
#include "LCDocument.h"

typedef enum _LCFieldOption
{
	// all fields
	LCFieldOption_ALL = 0,
	// all indexed fields
	LCFieldOption_INDEXED,
	// all fields which are not indexed
	LCFieldOption_UNINDEXED,
	// all fields which are indexed with termvectors enables
	LCFieldOption_INDEXED_WITH_TERMVECTOR,
	// all fields which are indexed but don't have termvectors enabled
	LCFieldOption_INDEXED_NO_TERMVECTOR,
	// all fields where termvectors are enabled. Please note that only standard termvector fields are returned
	LCFieldOption_TERMVECTOR,
	// all field with termvectors wiht positions enabled
	LCFieldOption_TERMVECTOR_WITH_POSITION,
	// all fields where termvectors with offset position are set
	LCFieldOption_TERMVECTOR_WITH_OFFSET,
	// all fields where termvectors with offset and position values set
	LCFieldOption_TERMVECTOR_WITH_POSITION_OFFSET
} LCFieldOption;

@interface LCIndexReader: NSObject <NSCopying>
{
	id <LCDirectory> directory;
	BOOL directoryOwner;
	BOOL closeDirectory;
	
	LCSegmentInfos *segmentInfos;
	// Lock writeLock
	BOOL stale;
	BOOL hasChanges;
}

+ (LCIndexReader *) openPath: (NSString *) path;
+ (LCIndexReader *) openDirectory: (id <LCDirectory>) directory;
/* Do NOT use -initWithDirectory:
 * it is designed to be override by subclass
 * Always use +openPath or +openDirectory.
 */
- (id) initWithDirectory: (id <LCDirectory>) directory;
- (id) initWithDirectory: (id <LCDirectory>) dir       
			segmentInfos: (LCSegmentInfos *) seg       
		  closeDirectory: (BOOL) close;
- (id) initWithDirectory: (id <LCDirectory>) dir       
			segmentInfos: (LCSegmentInfos *) seg       
		  closeDirectory: (BOOL) close
		  directoryOwner: (BOOL) owner;

- (id <LCDirectory>) directory;
+ (long) currentVersionAtPath: (NSString *) path;
+ (long) currentVersionWithDirectory: (id <LCDirectory>) dir;
- (NSArray *) termFrequencyVectors: (int) document;
- (id <LCTermFrequencyVector>) termFrequencyVector: (int) document
								   field: (NSString *) field;
+ (BOOL) indexExistsAtPath: (NSString *) dir;
+ (BOOL) indexExistsWithDirectory: (id <LCDirectory>) dir;
- (int) numberOfDocuments;
- (int) maximalDocument;
- (LCDocument *) document: (int) n;
- (BOOL) isDeleted: (int) n;
- (BOOL) hasDeletions;
- (BOOL) hasNorms: (NSString *) field;
- (NSData *) norms: (NSString *) field;
- (void) setNorms: (NSString *) field 
            bytes: (NSMutableData *) bytes offset: (int) offset;
- (void) setNorm: (int) doc field: (NSString *) field charValue: (char) value;
- (void) setNorm: (int) doc field: (NSString *) field floatValue: (float) value;
- (LCTermEnumerator *) termEnumerator;
- (LCTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) t;
- (long) documentFrequency: (LCTerm *) t;
- (id <LCTermDocuments>) termDocumentsWithTerm: (LCTerm *) term;
- (id <LCTermDocuments>) termDocuments;
- (id <LCTermPositions>) termPositionsWithTerm: (LCTerm *) term;
- (id <LCTermPositions>) termPositions;
- (void) deleteDocument: (int) docNum;
- (int) deleteTerm: (LCTerm *) term;
- (void) undeleteAll;
- (void) close;
- (NSArray *) fieldNames: (LCFieldOption) fieldOption;
+ (BOOL) isLocked: (id <LCDirectory>) dir;
- (BOOL) isLockedAtPath: (NSString *) dir;
- (void) unlock: (id <LCDirectory>) dir;

@end

@interface LCIndexReader (LCProtected)
- (void) doSetNorm: (int) doc field: (NSString *) field charValue: (char) value;
- (void) doDelete: (int) docNum;
- (void) doUndeleteAll;
- (void) commit;
- (void) doCommit;
- (void) doClose;
@end

#endif /* __LUCENE_INDEX_INDEX_READER__ */
