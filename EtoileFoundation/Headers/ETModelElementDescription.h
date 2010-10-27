/** <title>ETModelElementDescription</title>

	<abstract>A model description framework inspired by FAME 
	(http://scg.unibe.ch/wiki/projects/fame)</abstract>
 
	Copyright (C) 2009 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  July 2009
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETEntityDescription, ETUTI;

/** Abstract base class used by Model Description core classes. 

Also implements NestedElement and NamedElement protocols that exist in FAME/EMOF.

<chapter>
<heading>FAME and EtoileFoundation's Model Description</heading>

<section>
<heading>FAME Teminology Change Summary</heading>
Those changes were made to further simplify the FAME terminology which can get 
obscure since it overlaps with the host language object model, prevent any 
conflict with existing GNUstep/Cocoa API and reuse GNUstep/Cocoa naming habits.

We list the FAME term first, then its equivalent name in EtoileFoundation:
<deflist>
<item>FM3.Element</item><desc>ETModelElementDescription</desc>
<item>FM3.Class</item><desc>ETEntityDescription</desc>
<item>FM3.Property</item><desc>ETPropertyDescription</desc>
<item>FM3.RuntimeElement</item><desc>ETAdaptiveModelObject</desc>
<item>attributes (in Class)</item><desc>propertyDescriptions (in ETEntityDescription)</desc>
<item>allAttributes (in Class)</item><desc>allPropertyDescriptions (in ETEntityDescription)</desc>
<item>superclass (in Class)</item><desc>parent (in ETEntityDescription)</desc>
<item>class (in Property)</item><desc>owner (in ETPropertyDescription)</desc>
</deflist>
For the last point class vs owner, we can consider they have been merged into 
a single property in EtoileFoundation since they were redundant.
</section>

<section>
<heading>Additions to FAME</heading>
itemIdentifier has been added as a mean to get precise control over the UI 
generation with EtoileUI.
</section>

<heading>Removals to FAME/EMOF</heading>
NamedElement and NestedElement protocols don't exist explicitly.
</section>

</chapter> */
@interface ETModelElementDescription : NSObject
{
	NSString *_name;
	NSString *_itemIdentifier;
}

/** <override-subclass />
Returns a new self-description (aka meta-metamodel). */
+ (ETEntityDescription *) newEntityDescription;

/** Returns an autoreleased entity, property or package description.

See also -initWithName:. */
+ (id) descriptionWithName: (NSString *)name;

/** Initializes and returns an entity, property or package description.

You must only invoke this method on subclasses, otherwise nil is returned.

You should pass the property name in argument for a property description. And   
the class name for an entity description, the only exception is when the entity 
description applies to a prototype rather than a class.

Raises an NSInvalidArgumentException when the name is nil or already in use. */
- (id) initWithName: (NSString *)name;

/** Returns whether the receiver describes a property. */
- (BOOL) isPropertyDescription;
/** Returns whether the receiver describes an entity. */
- (BOOL) isEntityDescription;
/** Returns whether the receiver describes a package. */
- (BOOL) isPackageDescription;

/* Property getters/setters */

/** Returns the name of the entity, property or package. */
- (NSString *) name;
/** Sets the name of the entity, property or package. */
- (void) setName: (NSString *)name;
/** Returns the name that uniquely identify the receiver.

The name is a key path built by joining every names in the owner chain up to 
the root owner. The key path pattern is:
<code>ownerName*.receiverName</code>. 
The '+' sign indicates 'ownerName' can be repeated zero or multiple times.

Given a class 'Movie' and its property 'director'. The full names are:
<list>
<item>Movie for the class</item>
<item>Movie.director for the property</item>
</list>. */
- (NSString *) fullName;
/** Returns the element that owns the receiver.

For a property, the owner is the entity it belongs to.<br />
For an entity, there is no owner, unless the entity belongs to a package.<br />
For a package, there is no owner.

By default, returns nil. */
- (id) owner;

/* UI */

/** Returns a hint that precises how the receiver should be rendered. 
e.g. at UI level.

By default, returns nil.

See also -setIdemIdentifier:. */
- (NSString *) itemIdentifier;
/** Sets a hint that precises how the receiver should be rendered.

You can use this hint to identify which object to ouput, every time a new 
representation has to be generated based on the description.

ETModelDescriptionRenderer in EtoileUI uses it to look up a template item that  
will represent the property at the UI level. */
- (void) setItemIdentifier: (NSString *)anIdentifier;

/* Runtime Consistency Check */

/** <override-dummy />
Checks the receiver conforms to the FM3 constraint spec and adds a short warning
to the given array for each failure. 

A warning must be a NSString instance that describes the issue. Every warning 
should be created with -warningWithMessage:. */
- (void) checkConstraints: (NSMutableArray *)warnings;
/** Returns an autoreleased warning built with the given explanation. 

See -checkConstraints:. */
- (NSString *) warningWithMessage: (NSString *)msg;

/* Model Presentation */

/** Returns -name. */
- (NSString *) displayName;
/** <override-subclass />
Returns a short and human-readable description of the receiver type.

It must be derived from the class name. e.g. 'Package' for ETPackageDescription.

By default, returns 'Element'. */
- (NSString *) typeDescription;

@end
