/* See http://llvm.org/bugs/show_bug.cgi?id=4746 */
#undef __block
#include <unistd.h>
#define __block __attribute__((__blocks__(byref)))
