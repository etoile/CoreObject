#include "LCSmallFloat.h"
#include <UnitKit/UnitKit.h>

@interface TestSmallFloat: NSObject <UKTest>
@end

@implementation TestSmallFloat
- (float) orig_byteToFloat: (char) b
{
        if (b == 0) return 0.0f; // zero is a special case
        int mantissa = b & 7;
        int exponent = (b >> 3) & 31;
        int bits = ((exponent+(63-15)) << 24) | (mantissa << 21);
        
        /* LuceneKit: // Float.intBitsToFloat(bits);
        * Assume C follows IEEE standard.
        * Assum sizeof(float) == sizeof(int) == 4;
        */
        union
    {
                float fl;
                int il;
    } udata;
        udata.il = bits;
        return udata.fl;
}

- (char) orig_floatToByte: (float) f
{
        if (f < 0.0f)  // round negatives up to zero
                f = 0.0f;
        
        if (f == 0.0f) // zero is a special case
                return 0;
        
        //int bits = Float.floatToIntBits(f); // parse float into part s
        // Assum sizeof(float) == sizeof(int) == 4;
        // Assume C follows IEEE standard.
        union
    {
                float fl;
                int il;
    } udata;
        udata.fl = f;
        int bits = udata.il;

        int mantissa = (bits & 0xffffff) >> 21;
        int exponent = (((bits >> 24) & 0x7f) - 63) + 15;
        
        if (exponent > 31) {                          // overflow: use max value
                exponent = 31;
                mantissa = 7;
        }
        
        if (exponent < 0) { // underflow: use min value
                exponent = 0;
                mantissa = 1;
        }
        
        return (char)((exponent << 3) | mantissa);    // pack into a byte
}

- (void) testByteToFloat
{
  int i;
    for (i=0; i<256; i++) {
      float f1 = [self orig_byteToFloat: (char)i];
      float f2 = [LCSmallFloat byteToFloat:(char)i numberOfMantissaBits: 3 zeroExponent: 15];
      float f3 = [LCSmallFloat byte315ToFloat: (char)i];
      UKFloatsEqual(f1, f2, 0.000001f);
      UKFloatsEqual(f2, f3, 0.000001f);

      float f4 = [LCSmallFloat byteToFloat: (char)i numberOfMantissaBits: 5 zeroExponent: 2];
      float f5 = [LCSmallFloat byte52ToFloat: (char)i];
      UKFloatsEqual(f4, f5, 0.000001f);
    }
}

- (void) testFloatToByte
{
  srandom(0);
  int i;
  /* LuceneKit: // Float.intBitsToFloat(bits);
  * Assume C follows IEEE standard.
  * Assum sizeof(float) == sizeof(int) == 4;
  */
  union    {
                float fl;
                int il;
  } udata;
  // up iterations for more exhaustive test after changing something
  for (i=0; i<100000; i++) {
  udata.il = random();
  float f = udata.fl;
  if (f!=f) continue;    // skip NaN
  char b1 = [self orig_floatToByte: f];
      char b2 = [LCSmallFloat floatToByte: f numberOfMantissaBits: 3 zeroExponent: 15];
      char b3 = [LCSmallFloat floatToByte315: f];
	UKTrue(b1 == b2);
	UKTrue(b2 == b3);

      char b4 = [LCSmallFloat floatToByte: f numberOfMantissaBits: 5 zeroExponent: 2];
      char b5 = [LCSmallFloat floatToByte52: f];
	UKTrue(b4 == b5);
    }
}

@end
