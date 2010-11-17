#include "LCSmallFloat.h"

/** Floating point numbers smaller than 32 bits. */

union    {
                float fl;
                int il;
} udata;

float IntBitsToFloat(int b)
{
    /* LuceneKit: // Float.intBitsToFloat(bits);
    * Assume C follows IEEE standard.
    * Assum sizeof(float) == sizeof(int) == 4;
    */
#if 0
    union    {
                float fl;
                int il;
    } udata;
#endif
    udata.il = b;
    return udata.fl;
}

int FloatToIntBits (float f)
{
    /* C implement of Float.floatToIntBits() */
    // Assum sizeof(float) == sizeof(int) == 4;
    // Assume C follows IEEE standard.
#if 0
    union
    {
                float fl;
                int il;
    } udata;
#endif
    udata.fl = f;
    return udata.il;
}

@implementation LCSmallFloat

  /** Converts a 32 bit float to an 8 bit float.
   * <br>Values less than zero are all mapped to zero.
   * <br>Values are truncated (rounded down) to the nearest 8 bit value.
   * <br>Values between zero and the smallest representable value
   *  are rounded up.
   *
   * @param f the 32 bit float to be converted to an 8 bit float (byte)
   * @param numMantissaBits the number of mantissa bits to use in the byte, with the remainder to be used in the exponent
   * @param zeroExp the zero-point in the range of exponent values
   * @return the 8 bit float representation
   */
+ (char) floatToByte: (float) f numberOfMantissaBits: (int) numMantissaBits
         zeroExponent: (int) zeroExp
{
    // Adjustment from a float zero exponent to our zero exponent,
    // shifted over to our exponent position.
    int fzero = (63-zeroExp)<<numMantissaBits;
    int bits = FloatToIntBits(f);

    int smallfloat = bits >> (24-numMantissaBits);
    if (smallfloat < fzero) {
      return (bits<=0) ?
        (char)0   // negative numbers and zero both map to 0 byte
       :(char)1;  // underflow is mapped to smallest non-zero number.
    } else if (smallfloat >= fzero + 0x100) {
      return -1;  // overflow maps to largest number
    } else {
      return (char)(smallfloat - fzero);
    }
}

  /** Converts an 8 bit float to a 32 bit float. */
+ (float) byteToFloat: (char) b numberOfMantissaBits: (int) numMantissaBits
         zeroExponent: (int) zeroExp
{
    if (b == 0) return 0.0f;
    int bits = (b&0xff) << (24-numMantissaBits);
    bits += (63-zeroExp) << 24;
    return IntBitsToFloat(bits);
}

  //
  // Some specializations of the generic functions follow.
  // The generic functions are just as fast with current (1.5)
  // -server JVMs, but still slower with client JVMs.
  //

  /** floatToByte(b, mantissaBits=3, zeroExponent=15)
   * <br>smallest non-zero value = 5.820766E-10
   * <br>largest value = 7.5161928E9
   * <br>epsilon = 0.125
   */
+ (char) floatToByte315: (float) f
{
    int bits = FloatToIntBits(f);
    int smallfloat = bits >> (24-3);
    if (smallfloat < (63-15)<<3) {
      return (bits<=0) ? (char)0 : (char)1;
    }
    if (smallfloat >= ((63-15)<<3) + 0x100) {
      return -1;
    }
    return (char)(smallfloat - ((63-15)<<3));
 }

  /** byteToFloat(b, mantissaBits=3, zeroExponent=15) */
+ (float) byte315ToFloat: (char) b
{
    if (b == 0) return 0.0f;
    int bits = (b&0xff) << (24-3);
    bits += (63-15) << 24;
    return IntBitsToFloat(bits);
  }


  /** floatToByte(b, mantissaBits=5, zeroExponent=2)
   * <br>smallest nonzero value = 0.033203125
   * <br>largest value = 1984.0
   * <br>epsilon = 0.03125
   */
+ (char) floatToByte52: (float) f
{
    int bits = FloatToIntBits(f);
    int smallfloat = bits >> (24-5);
    if (smallfloat < (63-2)<<5) {
      return (bits<=0) ? (char)0 : (char)1;
    }
    if (smallfloat >= ((63-2)<<5) + 0x100) {
      return -1;
    }
    return (char)(smallfloat - ((63-2)<<5));
  }

  /** byteToFloat(b, mantissaBits=5, zeroExponent=2) */
+ (float) byte52ToFloat: (char) b
{
    if (b == 0) return 0.0f;
    int bits = (b&0xff) << (24-5);
    bits += (63-2) << 24;
    return IntBitsToFloat(bits);
}

@end
