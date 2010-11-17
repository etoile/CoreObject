#ifndef __LUCENE_UTIL_BIT_VECTOR__
#define __LUCENE_UTIL_BIT_VECTOR__

#include <Foundation/Foundation.h>
#include "LCDirectory.h"

/** An array of bits.
 * <author>Yen-Ju Chen</author>
 */
@interface LCBitVector: NSObject
{
	unsigned char *bits; // size of bits won't change. It is fixed in -initWithSize.
	int size;
	int count;
	int it;
}

/** <init/> Initialized to be able to contain n bits */
- (id) initWithSize: (int) n;
/** Set YES at bit */
- (void) setBit: (int) bit;
/** Set NO at bit */
- (void) clearBit: (int) bit;
/** Get bit value */
- (BOOL) bit: (int) bit;
/** Get size */
- (int) size;
/** Count the number of bits which are YES */
- (int) count;
/** Read from file */
- (void) writeToDirectory: (id <LCDirectory>) d
                 name: (NSString *) name;
/** Write to file */
- (id) initWithDirectory: (id <LCDirectory>) d
                 name: (NSString *) name;

@end

#endif /* __LUCENE_UTIL_BIT_VECTOR__ */
