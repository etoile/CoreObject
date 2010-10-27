/*
 *  Macros.h
 *  Jabber
 *
 *  Created by David Chisnall on 02/08/2005.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef GNUSTEP
#import "../Source/GNUstep.h"
#endif
#import "../Headers/Macros.h"

#define AUTORELEASED(x) [[[x alloc] init] autorelease]
#define RETAINED(x) [[x alloc] init]
