#ifndef __LUCENE_INDEX_FIELD_INFO__
#define __LUCENE_INDEX_FIELD_INFO__

#include <Foundation/Foundation.h>

@interface LCFieldInfo: NSObject
{
	NSString *name;
	BOOL isIndexed;
	int number;
	
	// true if term vector for this field should be stored
	BOOL storeTermVector;
	BOOL storeOffsetWithTermVector;
	BOOL storePositionWithTermVector;
	BOOL omitNorms;
}

- (id) initWithName: (NSString *) na
		  isIndexed: (BOOL) tk
			 number: (int) nu
	   storeTermVector: (BOOL) tv
	   storePositionWithTermVector: (BOOL) pos
	   storeOffsetWithTermVector: (BOOL) off
	   omitNorms: (BOOL) ons;
- (NSString *) name;
- (BOOL) isIndexed;
- (BOOL) isTermVectorStored;
- (BOOL) isOffsetWithTermVectorStored;
- (BOOL) isPositionWithTermVectorStored;
- (int) number;
- (BOOL) omitNorms;
- (void) setIndexed: (BOOL) b;
- (void) setTermVectorStored: (BOOL) b;
- (void) setPositionWithTermVectorStored: (BOOL) b;
- (void) setOffsetWithTermVectorStored: (BOOL) b;
- (void) setOmitNorms: (BOOL) b;

@end

#endif /* __LUCENE_INDEX_FIELD_INFO__ */
