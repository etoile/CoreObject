#include "LCHit.h"
#include "LCHits.h"
#include "LCDocument.h"
#include "GNUstep.h"

@interface LCHit (LCPrivate)
- (void) fetchTheHit;
@end

@implementation LCHit

- (id) init
{
	self = [super init];
	doc = nil;
	resolved = NO;
	hits = nil;
	return self;
}

- (id) initWithHits: (LCHits *) h index: (int) index
{
	self = [self init];
	ASSIGN(hits, h);
	hitNumber = index;
	return self;
}

- (void) dealloc
{
	DESTROY(hits);
	[super dealloc];
}

- (LCDocument *) document
{
	if (!resolved) [self fetchTheHit];
	return doc;
}

- (float) score
{
	return [hits score: hitNumber];
}

- (int) identifier
{
	return [hits identifier: hitNumber];
}

- (void) fetchTheHit
{
	doc = [hits document: hitNumber];
	resolved = YES;
}

- (float) boost
{
	return [[self document] boost];
}

- (NSString *) stringForField: (NSString *) name
{
	return [[self document] stringForField: name];
}

- (NSString *) description
{
	NSMutableString *buffer = [[NSMutableString alloc] init];
	[buffer appendFormat: @"Hit<%@ [%d] ", hits, hitNumber];
	if (resolved) {
		[buffer appendString: @"resolved>"];
	} else {
		[buffer appendString: @"unresolved>"];
	}
	return AUTORELEASE(buffer);
}

@end

