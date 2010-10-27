/**
 * Generate an NSDictionary from the specified command-line options.  
 *
 * optString is a C string containing getopt-compatible options.  argc and argv
 * are the same as those passed into main().  The returned dictionary contains
 * NSNumbers representing the Bool values YES and NO for options that are
 * present or absent, and NSStrings containing optional parameters for those
 * that contain them.
 *
 * Consider the invocation: 
 *
 * NSDictionary * opts = ETGetOptionsDictionary("bf:", argc, argv);
 *
 * When the app is invoked with -b -f foo, this will return the dictionary:
 * { b = 1 ; f = foo; }
 * When the app is invoked with -f "bar wibble", it will return the following: 
 * { b = 0 ; f = "bar wibble"; }
 *
 * Invalid options will cause an InvalidOption exception to be thrown.
 */
NSDictionary *ETGetOptionsDictionary(char *optString, int argc, char **argv);
