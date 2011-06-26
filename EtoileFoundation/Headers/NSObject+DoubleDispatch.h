/**
	<abstract>Double dispatch facility</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
	License:  Modified BSD (see COPYING)
 */
 
#import <Foundation/NSObject.h>

/** @group Language Extensions

This category provides a visitor which supports double-dispatch on all
visited objects without implementing extra methods (such as 
<em>accept:</em> on the visited object side).

For a more detailed discussion, see -visit:.

Here is a visitor example:

<example>

@interface ETView : NSView
@end

@interface UIVisitor : NSObject
@end

@implementation ETView

- (NSString *) typePrefix
{
	return @"ET";
}

@end

// To start using the visitor, instantiate a visitor and do [visitor visit: someWindow]
@implementation UIVisitor

// visitXXX methods return id, but returning void would be valid

- (id) visitWindow: (NSWindow *)aWindow
{
	NSLog(@"Visiting window %@", aWindow);
	return [self visit: [aWindow contentView]];
}

- (id) visitView: (NSView *)aView
{
	NSLog(@"Visiting view %@", aView);
	for (NSView *subview in [aView subviews])
	{
		[self visit: subview];
	}
	return nil;
}

// Show how you can include the class name prefix and how such a method has 
// priority over a method without any type prefix such as -visitView:.
- (id) visitETView: (ETView *)aSpecialView
{
	NSLog(@"Visiting special view %@", aSpecialView);
	return nil;
}

@end
</example> */
@interface NSObject (DoubleDispatch)

/** <override-dummy />
Returns the method name prefix used to build the method name to be invoked 
by the double dispatch.

By default, returns <em>visit</em>.

Can be overriden to return a custom prefix such as <em>visit</em>.

See also -visit:. */
- (NSString *) doubleDispatchPrefix;

/** Tries to build a method name based on the given object type and invoke it.

For example, if you have a NSView, and you pass it as an argument to -visit:, 
the selector <em>visitNSView:</em> is built and invoked with the given view on 
the receiver. If the receiver doesn't respond to <em>visitNSView:</em>, then 
<em>visitView:</em> is built by trimming the class name prefix, and invoked. 
If the receiver still doesn't respond the last built selector, then it fails 
silently and returns nil.<br />
Class name prefix are trimmed based on the value returned by 
-[NSObject(Etoile) typePrefix]. You can override this last method to return 
a custom prefix, by default it returns <em>NS</em>.

If you want to use another method name prefix than <em>visit</em> (e.g. to build 
a selector such as <em>renderView:</em>), -doubleDispatchPrefix can be overriden.

Subclasses can override this method, if they want to customize the 
double-dispatch behavior. */
- (id) visit: (id)object;

/** Does the same than -visit: but reports whether a double-dispatch method 
was succesfully invoked by setting performed to YES, or NO when no such method 
was found.

See also -visit: and -supportsDoubleDispatchWithObject:.

This method is called by -visit: and implements the double-dispatch logic. */
- (id) visit: (id)object result: (BOOL *)performed;

/** Returns whether the receiver implements a double dispatch method that 
corresponds to the given object type. 

This method serves a similar purpose than -[NSObject respondsToSelector:].

See also -visit:. */
- (BOOL) supportsDoubleDispatchWithObject: (id)object;

/** <override-dummy />
Builds and returns the selector to be invoked for a double dispatch on the 
given type.

For a detailed example, see -visit:.

Can be overriden in subclasses to implement an alternative strategy to build 
the method names targeted by the double dispatch. */
- (SEL) doubleDispatchSelectorWithObject: (id)object ofType: (NSString *)aType;

/** Tries to invoke the selector with the given object as first argument, and 
returns either the value returned by the invoked method or nil.

If the receiver doesn't respond to the selector, performed is set to NO and nil 
is returned, otherwise performed is set YES. */
- (id) tryToPerformSelector: (SEL)selector withObject: (id)object result: (BOOL *)performed;

@end
