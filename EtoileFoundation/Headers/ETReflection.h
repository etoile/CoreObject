/**
	<abstract>Mirror-based reflection for Etoile</abstract>
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETCollection.h>

@class ETUTI;

/** @group Reflection */
@protocol ETMirror <NSObject>
- (NSString *) name;
- (ETUTI *) type;
@end


/** @group Reflection */
@protocol ETClassMirror <ETMirror, ETCollection>
- (id <ETClassMirror>) superclassMirror;
- (NSArray *) subclassMirrors;
- (NSArray *) allSubclassMirrors;
/**
 * Returns those protocols explicitly adopted by this class.
 */
- (NSArray *) adoptedProtocolMirrors;
/**
 * Returns all protocols adopted by this class, including those adopted by
 * means of class inheritance and by protocol inheritance.
 */
- (NSArray *) allAdoptedProtocolMirrors;
- (NSArray *) methodMirrors;
- (NSArray *) allMethodMirrors;
- (NSArray *) instanceVariableMirrors;
- (NSArray *) allInstanceVariableMirrors;
- (BOOL) isMetaClass;
- (NSArray *) instanceVariableMirrorsWithOwnerMirror: (id <ETMirror>)aMirror;
- (NSArray *) allInstanceVariableMirrorsWithOwnerMirror: (id <ETMirror>)aMirror;
@end


/** @group Reflection */
@protocol ETObjectMirror <ETMirror, ETCollection>
- (id) representedObject;
- (id <ETClassMirror>) classMirror;
- (id <ETClassMirror>) superclassMirror;
- (id <ETObjectMirror>) prototypeMirror;
- (NSArray *) instanceVariableMirrors;
- (NSArray *) allInstanceVariableMirrors;
- (NSArray *) methodMirrors;
- (NSArray *) allMethodMirrors;
- (NSArray *) slotMirrors;
- (NSArray *) allSlotMirrors;
- (BOOL) isPrototype;
@end


/** @group Reflection */
@protocol ETProtocolMirror <ETMirror, ETCollection>
- (NSArray *) ancestorProtocolMirrors;
- (NSArray *) allAncestorProtocolMirrors;
- (NSArray *) methodMirrors;
- (NSArray *) allMethodMirrors;
@end


/** @group Reflection */
@protocol ETMethodMirror <ETMirror>
- (BOOL) isClassMethod;
@end


/** @group Reflection */
@protocol ETInstanceVariableMirror <ETMirror>
@end


/** @group Reflection */
@interface ETReflection : NSObject
{
}
+ (id <ETObjectMirror>) reflectObject: (id)anObject;
+ (id <ETClassMirror>) reflectClass: (Class)aClass;
+ (id <ETClassMirror>) reflectClassWithName: (NSString *)className;
+ (id <ETProtocolMirror>) reflectProtocolWithName: (NSString *)protocolName;
+ (id <ETProtocolMirror>) reflectProtocol: (Protocol *)aProtocol;
@end
