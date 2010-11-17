#ifndef __LuceneKit_Util_NSData_Additions__
#define __LuceneKit_Util_NSData_Additions__


#include <Foundation/Foundation.h>

/** Compress and decompress data.
 * NSData have no idea whether the data is compressed.
* Users are responsible for tracking it.
* Decompress an un-compressedData give a unpredictable result.
* zlib is used for compression.
*/

@interface NSData (LuceneKit_Util)
/** compress date */
- (NSData *) compressedData;
/** decompress data */
- (NSData *) decompressedData;

@end

#endif /* __LuceneKit_Util_NSData_Additions__ */
