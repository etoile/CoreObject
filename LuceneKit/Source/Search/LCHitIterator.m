#include "LCHitIterator.h"
#include "LCHits.h"
#include "LCHit.h"
#include "GNUstep.h"

@implementation LCHitIterator

- (id) init
{
	self = [super init];
	hitNumber = 0;
	return self;
}

- (id) initWithHits: (LCHits *) h
{
	self = [self init];
	ASSIGN(hits, h);
	return self;
}

- (void) dealloc
{
	DESTROY(hits);
	[super dealloc];
}

- (BOOL) hasNext
{
	if (hitNumber < [hits count])
		return YES;
	return NO;
} 

- (LCHit *) next
{
	if (hitNumber == [hits count])
	{
		NSLog(@"Not such element exception");
		return nil;
	}
	
	LCHit *next = [[LCHit alloc] initWithHits: hits index: hitNumber];
	hitNumber++;
	
	return AUTORELEASE(next);
}

- (int) count
{
	return [hits count];
}

@end
