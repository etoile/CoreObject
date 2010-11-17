#include <LuceneKit/LuceneKit.h>
#include <UnitKit/UnitKit.h>
#include "GNUstep/GNUstep.h"

@interface TestIndexWriterMerging: NSObject <UKTest>
@end

@implementation TestIndexWriterMerging

- (void) fillIndex: (id <LCDirectory>) dir start: (int) start
         numDocs: (int) numDocs
{
  LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: dir
                  analyzer: [[LCSimpleAnalyzer alloc] init]
		create: YES];
  [writer setMergeFactor: 2];
  [writer setMaxBufferedDocuments: 2];

  int i;
  for (i = start; i < start+numDocs; i++) {
    LCField *field = [[LCField alloc] initWithName: @"count"
				string: [NSString stringWithFormat: @"%d", i]
			store: LCStore_YES
			index: LCIndex_Tokenized];
    LCDocument *document = [[LCDocument alloc] init];
    [document addField: field];
    [writer addDocument: document];
    DESTROY(document);
    DESTROY(field);
  }
  [writer close];
}

- (BOOL) verifyIndex: (id <LCDirectory>) dir startAt: (int) startAt
{
  BOOL failed = NO;
  LCIndexReader *reader = [LCIndexReader openDirectory: dir];

  int i, max = [reader maximalDocument];
  for (i = 0; i < max; i++) {
    LCDocument *temp = [reader document: i];
    if (NO == [[[temp field: @"count"] string] isEqualToString: [NSString stringWithFormat: @"%d", startAt+i]]) {
      failed = YES;
    }
         
  }
  return failed;
}

- (void) testMerging
{
  int num=100;
  LCRAMDirectory *indexA = [[LCRAMDirectory alloc] init];
  LCRAMDirectory *indexB = [[LCRAMDirectory alloc] init];

  [self fillIndex: indexA start: 0 numDocs: num];
  BOOL failed = [self verifyIndex: indexA startAt: 0];
  UKFalse(failed);

  [self fillIndex: indexB start: num numDocs: num];
  failed = [self verifyIndex: indexB startAt: num];
  UKFalse(failed);

  LCRAMDirectory *merged = [[LCRAMDirectory alloc] init];
  LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: merged
			analyzer: [[LCSimpleAnalyzer alloc] init]
			create: YES];
  [writer setMergeFactor: 2];
  [writer addIndexesWithDirectories: [NSArray arrayWithObjects: indexA, indexB, nil]];
  [writer close];
  [merged close];

  failed = [self verifyIndex: merged startAt: 0];
  UKFalse(failed);
}

@end
