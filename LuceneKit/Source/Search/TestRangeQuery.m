#include <UnitKit/UnitKit.h>
#include "LuceneKit.h"
#include "GNUstep.h"

@interface TestRangeQuery: LCRangeQuery <UKTest>
{
  int docCount;
  LCRAMDirectory *dir;
}
@end

@implementation TestRangeQuery
- (void) insertDoc: (LCIndexWriter *) writer : (NSString *) content
{
  LCDocument *doc = [[LCDocument alloc] init];
  LCField *field = [[LCField alloc] initWithName: @"id"
			string: [NSString stringWithFormat: @"id%d", docCount]
			store: LCStore_YES
			index: LCIndex_Untokenized];
  [doc addField: field];
  DESTROY(field);
  field = [[LCField alloc] initWithName: @"content"
			string: content
			store: LCStore_NO
			index: LCIndex_Tokenized];
  [doc addField: field];
  DESTROY(field);
  [writer addDocument: doc];
  docCount++;
}

- (void) addDoc: (NSString *) content
{
  LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: dir
		analyzer: AUTORELEASE([[LCWhitespaceAnalyzer alloc] init])
		create: NO];
  [self insertDoc: writer : content];
  [writer close];
  DESTROY(writer);
}

- (void) initIndex: (NSArray *) values
{
  LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: dir
	analyzer: AUTORELEASE([[LCWhitespaceAnalyzer alloc] init])
	create: YES];
  int i;
  for (i = 0; i < [values count]; i++)
  {
    [self insertDoc: writer : [values objectAtIndex: i]];
  }
  [writer close];
  DESTROY(writer);
}

- (void) testInclusive
{
  LCTerm *l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  LCTerm *u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  LCQuery *query = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  [self initIndex: [NSArray arrayWithObjects: @"A", @"B", @"C", @"D", nil]];
  LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  LCHits *hits = [searcher search: query];
  UKIntsEqual(3, [hits count]);
  [searcher close];

  [self initIndex: [NSArray arrayWithObjects: @"A", @"B", @"D", nil]];
  searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  hits = [searcher search: query];
  UKIntsEqual(2, [hits count]);
  [searcher close];

  [self addDoc: @"C"];
  searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  hits = [searcher search: query];
  UKIntsEqual(3, [hits count]);
}

- (void) testExclusive
{
  LCTerm *l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  LCTerm *u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  LCQuery *query = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: NO];
  [self initIndex: [NSArray arrayWithObjects: @"A", @"B", @"C", @"D", nil]];
  LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  LCHits *hits = [searcher search: query];
  UKIntsEqual(1, [hits count]);
  [searcher close];

  [self initIndex: [NSArray arrayWithObjects: @"A", @"B", @"D", nil]];
  searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  hits = [searcher search: query];
  UKIntsEqual(1, [hits count]);
  [searcher close];

  [self addDoc: @"C"];
  searcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
  hits = [searcher search: query];
  UKIntsEqual(1, [hits count]);
  [searcher close];
}

- (void) testEqualsHash
{
  LCTerm *l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  LCTerm *u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  LCQuery *query = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  [query setBoost: 1.0f];
  l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  LCQuery *other = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  [other setBoost: 1.0f];
  
  UKTrue([query isEqual: query]);
  UKTrue([query isEqual: other]);
  UKIntsEqual([query hash], [other hash]);

  [other setBoost: 2.0f];
  UKFalse([query isEqual: other]);

  l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  u = [[LCTerm alloc] initWithField: @"notcontent" text: @"C"];
  other = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  UKFalse([query isEqual: other]);

  l = [[LCTerm alloc] initWithField: @"content" text: @"X"];
  u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  other = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  UKFalse([query isEqual: other]);

  l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  u = [[LCTerm alloc] initWithField: @"content" text: @"Z"];
  other = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  UKFalse([query isEqual: other]);

  u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  query = [[LCRangeQuery alloc] initWithLowerTerm: nil upperTerm: u
				inclusive: YES];
  other = [[LCRangeQuery alloc] initWithLowerTerm: nil upperTerm: u
				inclusive: YES];
  UKTrue([query isEqual: other]);
  UKIntsEqual([query hash], [other hash]);

  query = [[LCRangeQuery alloc] initWithLowerTerm: u upperTerm: nil
				inclusive: YES];
  other = [[LCRangeQuery alloc] initWithLowerTerm: u upperTerm: nil
				inclusive: YES];
  UKTrue([query isEqual: other]);
  UKIntsEqual([query hash], [other hash]);

  query = [[LCRangeQuery alloc] initWithLowerTerm: u upperTerm: nil
				inclusive: YES];
  other = [[LCRangeQuery alloc] initWithLowerTerm: nil upperTerm: u 
				inclusive: YES];
  UKFalse([query isEqual: other]);

  l = [[LCTerm alloc] initWithField: @"content" text: @"A"];
  u = [[LCTerm alloc] initWithField: @"content" text: @"C"];
  query = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: NO];
  other = [[LCRangeQuery alloc] initWithLowerTerm: l upperTerm: u
				inclusive: YES];
  UKFalse([query isEqual: other]);
}

- (id) init
{
  self = [super init];
  docCount = 0;
  dir = [[LCRAMDirectory alloc] init];
  return self;
}

- (void) dealloc
{
  DESTROY(dir);
  [super dealloc];
}

@end
