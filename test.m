#include <stdlib.h>
#include <stdio.h>

#if __has_feature(objc_generics)
static int has_generics = 1;
#else
static int has_generics = 0;
#endif
 
#if __has_feature(nullability)
static int has_nullability = 1;
#else
static int has_nullability = 0;
#endif

int main(int argc, const char **argv) {
    printf("has generics: %d, has nullability %d\n", has_generics, has_nullability);
    return 0;
}

