#include "LCQueryFilter.h"
#include "LCHitCollector.h"
#include "LCIndexSearcher.h"
#include "LCBitVector.h"
#include "LCQuery.h"
#include "GNUstep.h"

@interface LCQueryFilterHitCollector: LCHitCollector
{
	LCBitVector * bits;
}
- (id) initWithBits: (LCBitVector *) bits;
@end

@implementation LCQueryFilterHitCollector: LCHitCollector
- (id) initWithBits: (LCBitVector *) b
{
	self = [self init];
	ASSIGN(bits, b);
	return self;
}

- (void) dealloc
{
  DESTROY(bits);
  [super dealloc];
}

- (void) collect: (int) doc score: (float) score
{
	[bits setBit: doc];
}
@end

@implementation LCQueryFilter
- (id) initWithQuery: (LCQuery *) q
{
	self = [self init];
	cache = nil;
	ASSIGN(query, q);
	return self;
}

- (void) dealloc
{
  DESTROY(query);
  [super dealloc];
}

- (LCQuery *) query
{
	return query;
}

- (LCBitVector *) bits: (LCIndexReader *) reader
{
	if (cache == nil)
	{
          cache = AUTORELEASE([[NSMutableDictionary alloc] init]);
	}
	
	LCBitVector *cached = [cache objectForKey: reader];
	if (cached != nil) return cached;
	
	LCBitVector *bits = [(LCBitVector *)[LCBitVector alloc] initWithSize: [reader maximalDocument]];
	LCQueryFilterHitCollector *hc = [[LCQueryFilterHitCollector alloc] initWithBits: bits];
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithReader: reader];
	[searcher search: query hitCollector: hc];
	[cache setObject: bits forKey: reader];
	RELEASE(searcher);
	RELEASE(hc);
	
	return AUTORELEASE(bits);
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"LCQueryFilter(%@)", query];
}

- (NSUInteger) hash
{
  return [query hash]^0x923F64B9;
}

- (BOOL) isEqual: (id) o
{
  if (!([o isKindOfClass: [LCQueryFilter class]])) return NO;
  return [query isEqual: [(LCQueryFilter *)o query]];
}

@end
