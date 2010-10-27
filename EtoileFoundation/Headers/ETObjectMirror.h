/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETReflection.h>
#import <EtoileFoundation/runtime.h>

@interface ETObjectMirror : NSObject <ETObjectMirror>
{
	id _object;
}
+ (id) mirrorWithObject: (id)object;
- (id) initWithObject: (id)object;
- (id) representedObject;
@end

