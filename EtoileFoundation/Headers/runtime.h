/**
 * Includes the Objective-C 2.0 runtime library functions.
 *
 * With libobjc2 or OS X this means including objc/runtime.h, and for the
 * old GNU runtime it means importing runtime.h from the ObjectiveC2 
 * compatability framework.
 */
#if GNU_RUNTIME_VERSION == 1
#import <ObjectiveC2/runtime.h>
#else
#import <objc/runtime.h>
#endif
