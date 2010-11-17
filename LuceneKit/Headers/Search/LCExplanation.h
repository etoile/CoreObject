#ifndef __LUCENE_SEARCH_EXPLANATION__
#define __LUCENE_SEARCH_EXPLANATION__

#include <Foundation/Foundation.h> // Serializable

@interface LCExplanation: NSObject
{
	float value; // the value of this node
	NSString *representation; // what it represents
	NSMutableArray *details; // sub-explanations
}

- (id) initWithValue: (float) v representation: (NSString *) d;
- (float) value;
- (void) setValue: (float) value;
	 /* LuceneKit: replace description */
- (NSString *) representation; 
- (void) setRepresentation: (NSString *) d;
- (NSArray *) details;
- (void) addDetail: (LCExplanation *) details;
- (NSString *) descriptionWithHTML;
@end
#endif /* __LUCENE_SEARCH_EXPLANATION__ */
