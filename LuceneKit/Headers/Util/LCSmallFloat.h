#ifndef __LuceneKit_Util_SmallFont__
#define __LuceneKit_Util_SmallFont__

#include <Foundation/Foundation.h>

float IntBitsToFloat(int b);
int FloatToIntBits (float f);

@interface LCSmallFloat: NSObject

+ (char) floatToByte: (float) f numberOfMantissaBits: (int) numMantissaBits
         zeroExponent: (int) zeroExp;
+ (float) byteToFloat: (char) b numberOfMantissaBits: (int) numMantissaBits
         zeroExponent: (int) zeroExp;

+ (char) floatToByte315: (float) f;
+ (float) byte315ToFloat: (char) b;

+ (char) floatToByte52: (float) f;
+ (float) byte52ToFloat: (char) b;

@end

#endif /* __LuceneKit_Util_SmallFont__ */
