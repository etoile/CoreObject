#include "LCTermInfo.h"

/** A TermInfo is the record of information stored for a term.*/
@implementation LCTermInfo

- (id) init
{
	self = [super init];
	docFreq = 0;
	freqPointer = 0;
	proxPointer = 0;
	skipOffset = 0;
	return self;
}

- (id) initWithDocFreq: (long) df 
           freqPointer: (long long) fp 
		   proxPointer: (long long) pp
{
	self = [self init];
	docFreq = df;
	freqPointer = fp;
	proxPointer = pp;
	skipOffset = 0;
	return self;
}

- (id) initWithTermInfo: (LCTermInfo *) ti
{
	self = [self initWithDocFreq: [ti documentFrequency]
					 freqPointer: [ti freqPointer]
					 proxPointer: [ti proxPointer]];
	skipOffset = [ti skipOffset];
	return self;
}

- (long) documentFrequency 
{
	return docFreq;
}

- (long long) freqPointer
{
	return freqPointer;
}

- (long long) proxPointer
{
	return proxPointer;
}

- (long) skipOffset
{
	return skipOffset;
}

- (void) setTermInfo: (LCTermInfo *) ti
{
	docFreq = [ti documentFrequency];
	freqPointer = [ti freqPointer];
	proxPointer = [ti proxPointer];
	skipOffset = [ti skipOffset];
}

- (void) setDocumentFrequency: (long) doc
{
	docFreq = doc;
}

- (void) setFreqPointer: (long long) freq
{
	freqPointer = freq;
}

- (void) setProxPointer: (long long) prox
{
	proxPointer = prox;
}

- (void) setSkipOffset: (long) skip
{
	skipOffset = skip;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"LCTermInfo: docFreq %ld freqPointer %lld proxPointer %lld skipOffset %ld", docFreq, freqPointer, proxPointer, skipOffset];
}

- (id) copyWithZone: (NSZone *) zone
{
	LCTermInfo *other = [[LCTermInfo allocWithZone: zone] init];
	[other setDocumentFrequency: docFreq];
	[other setFreqPointer: freqPointer];
	[other setProxPointer: proxPointer];
	[other setSkipOffset: skipOffset];
	return other;
}

@end
