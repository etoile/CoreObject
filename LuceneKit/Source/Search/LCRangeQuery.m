#include "LCRangeQuery.h"
#include "LCBooleanQuery.h"
#include "LCTermQuery.h"
#include "LCTerm.h"
#include "LCTermEnum.h"
#include "LCIndexReader.h"
#include "NSString+Additions.h"
#include "LCSmallFloat.h"
#include "GNUstep.h"

@implementation LCRangeQuery
- (id) initWithLowerTerm: (LCTerm *) lower upperTerm: (LCTerm *) upper
                inclusive: (BOOL) incl
{
  if (lower == nil && upper == nil)
  {
    NSLog(@"At least one term must be non-null");
    return nil;
  }
  if (lower && upper && [[lower field] isEqualToString: [upper field]] == NO)
  {
    NSLog(@"Both terms must be for the same field");
    return nil;
  }

  self = [self init];

  lowerTerm = [[LCTerm alloc] initWithField: [upper field] text: @""];
  if (lower)
  {
    [lowerTerm setTerm: lower];
  }

  if (upper)
  {
    upperTerm = [[LCTerm alloc] initWithField: [upper field] text: [upper text]];
  }
  else
  {
    upperTerm = nil;
  }

  inclusive = incl;

  return self;
}

- (void) dealloc
{
  DESTROY(lowerTerm);
  DESTROY(upperTerm);
  [super dealloc];
}

- (LCQuery *) rewrite: (LCIndexReader *) reader
{
  LCBooleanQuery *query = [[LCBooleanQuery alloc] initWithCoordination: YES];
  LCTermEnumerator *enumerator = [reader termEnumeratorWithTerm: lowerTerm];

  BOOL checkLower = NO;
  if (inclusive == NO) // make adjustments to set to exclusive
    checkLower = YES;

  NSString *testField = [self field];

  do {
    LCTerm *term = [enumerator term];
    if (term && [[term field] isEqualToString: testField]) {
      if ((checkLower == NO) || ([[term text] compare: [lowerTerm text]] == NSOrderedDescending))
      {
        checkLower = NO;
        if (upperTerm)
        {
          int compare = [[upperTerm text] compare: [term text]];
          /* if beyond the upper term, or is exclusive and
           * this is equal to the upper term, break out */
          if ((compare == NSOrderedAscending) || ((inclusive == NO) && (compare == NSOrderedSame)))
            break;
        }
        LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: term]; // found a match
        [tq setBoost: [self boost]]; // set the boost
        [query addQuery: tq occur: LCOccur_SHOULD]; // add to query
        DESTROY(tq);
      }
    }
    else
    {
      break;
    }
  }
  while ([enumerator hasNextTerm]);

  [enumerator close];

  return AUTORELEASE(query);
}

- (NSString *) field
{
  return (lowerTerm) ? [lowerTerm field] : [upperTerm field];
}

- (LCTerm *) lowerTerm
{
  return lowerTerm;
}

- (LCTerm *) upperTerm
{
  return upperTerm;
}

- (BOOL) isInclusive
{
  return inclusive;
}

- (NSString *) descriptionWithField: (NSString *) field
{
  NSMutableString *ms = [[NSMutableString alloc] init];
  if ([[self field] isEqualToString: field] == NO)
  {
    [ms appendFormat: @"%@:", [self field]];
  }
  [ms appendString: (inclusive ? @"[" : @"{")];
  [ms appendString: (lowerTerm) ? (NSString*)[lowerTerm text] : (NSString*)@"null"];
  [ms appendString: @" TO "];
  [ms appendString: (upperTerm) ? (NSString*)[upperTerm text] : (NSString*)@"null"];
  [ms appendString: (inclusive ? @"]" : @"}")];
  [ms appendString: LCStringFromBoost([self boost])];
  return AUTORELEASE(ms);
}

- (BOOL) isEqual: (id) o
{
  if (self == o) return YES;
  if ([o isKindOfClass: [LCRangeQuery class]] == NO) return NO;
  LCRangeQuery *other = (LCRangeQuery *) o;
  if ([self boost] != [other boost]) return NO;
  if ([self isInclusive] != [other isInclusive]) return NO;
  if (lowerTerm)
  {
    if ([[self lowerTerm] isEqual: [other lowerTerm]] == NO)
      return NO;
  }
  else
  {
    if ([other lowerTerm] != nil)
      return NO;
  }
  if (upperTerm)
  {
    if ([[self upperTerm] isEqual: [other upperTerm]] == NO)
      return NO;
  }
  else
  {
    if ([other upperTerm] != nil)
      return NO;
  }
  return YES;
}

- (NSUInteger) hash
{
  int h = FloatToIntBits([self boost]);
  h ^= (lowerTerm ? [lowerTerm hash] : 0);
  // reversible mix to make lower and upper position dependent and
  // to prevent them from cancelling out.
  h ^= (h << 25) | (h >> 8); // FIXME: should be (h >>> 8)
  h ^= (upperTerm ? [upperTerm hash] : 0);
  h ^= (inclusive ? 0x2742E74A : 0);
  return h;
}


@end

