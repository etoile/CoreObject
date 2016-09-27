/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#if (TARGET_OS_IPHONE)
#   import <CoreObject/COCocoaTouchCompatibility.h>
#else
#   import <AppKit/AppKit.h>
#endif
#import <EtoileFoundation/EtoileFoundation.h>

@interface COColorToHTMLString : NSValueTransformer
@end
