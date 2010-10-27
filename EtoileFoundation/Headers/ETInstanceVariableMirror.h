/** <title>ETInstanceVariableMirror</title>

	<abstract>Mirror class that represents an Objective-C instance 
	variable.</abstract>

	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETReflection.h>
#import <EtoileFoundation/runtime.h>


@interface ETInstanceVariableMirror : NSObject <ETInstanceVariableMirror>
{
	Ivar _ivar;
	id <ETMirror> _ownerMirror;
	id <ETObjectMirror> _cachedValueMirror;
}

/** <init />
Initializes and returns an instance variable mirror for the given runtime 
underlying representation and a owner mirror.

The owner mirror must conform to either ETClassMirror or ETObjectMirror protocols. */
- (id) initWithIvar: (Ivar)ivar ownerMirror: (id <ETMirror>)aMirror;
/** Returns a new autoreleased instance variable mirror for the given runtime 
underlying representation and an optional owner mirror.

See also -initWithIvar:ownerMirror:. */
+ (id) mirrorWithIvar: (Ivar)ivar ownerMirror: (id <ETMirror>)aMirror;

/** Returns the name that was used to declare the instance variable. */
- (NSString *) name;

/** Returns the mirror representing the runtime construct where the instance 
variable is declared or located. */
- (id <ETMirror>) ownerMirror;
/** Returns the mirror representing the object where the instance variable is 
located and its value stored.

Will return nil when the owner mirror doesn't conform to ETObjectMirror protocol. */
- (id <ETObjectMirror>) ownerObjectMirror;

/** Returns the object type of the instance variable as an UTI. */
- (ETUTI *) type;
/** Returns either class name or the type encoding name of the instance 
variable. The class name is returned when the value is an object, otherwise the 
the type encoding name is returned.

If -value returns nil and the type encoding denotes an object, take note the 
type encoding name is returned since the object type can only be looked up 
dynamically (by querying the object referenced by the instance variable). */
- (NSString *) typeName;
/** Returns the underlying runtime basic type (object, int, char, struct etc.) 
associated with the instance variable. 

These runtime basic types are encoded as character sequences. To interpret the 
returned value, see the runtime documentation. */
- (const char *) typeEncoding;
/** Returns whether the instance variable value is an object or not. */
- (BOOL) isObjectType;

/** Returns the value stored in the instance variable. 

If the instance variable type is a primitive type, nil is returned, unless the 
type encoding corresponds to a number or a structure such as NSRect, NSSize, 
NSPoint and NSRange. In this case, the returned value is respectively an 
NSNumber or NSValue object that boxes the primitive value. */
- (id) value;
/** Sets the value stored in the instance variable. 

If the instance variable type is a primitive type, the value cannot be set, 
unless the type encoding corresponds to a number or a structure such as NSRect, 
NSSize, NSPoint and NSRange. In this case, you can pass the primitive value 
boxed respectively in an NSNumber or NSValue object.

If value is an object and the instance variable type is a primitive type, in 
case no primitive value matching the expected type can be unboxed, an 
NSInvalidArgumentException is raised. <br />
For example, if value is a NSString and the instance variable is a NSRect, the 
exception reason will be: NSString does not recognize the selector -rectValue. */
- (void) setValue: (id)value;
/** Returns a mirror representing the value stored in the instance variable when 
the value is an object.

Returns nil when the value is a primitive type. */
- (id <ETObjectMirror>) valueMirror;

@end
