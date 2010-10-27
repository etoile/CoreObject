/*
	Mirror-based reflection for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETCollection.h>

@class ETUTI;

@protocol ETMirror <NSObject>
- (NSString *) name;
- (ETUTI *) type;
@end


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


@protocol ETProtocolMirror <ETMirror, ETCollection>
- (NSArray *) ancestorProtocolMirrors;
- (NSArray *) allAncestorProtocolMirrors;
- (NSArray *) methodMirrors;
- (NSArray *) allMethodMirrors;
@end


@protocol ETMethodMirror <ETMirror>
- (BOOL) isClassMethod;
@end


@protocol ETInstanceVariableMirror <ETMirror>
@end



@interface ETReflection : NSObject
{
}
+ (id <ETObjectMirror>) reflectObject: (id)anObject;
+ (id <ETClassMirror>) reflectClass: (Class)aClass;
+ (id <ETClassMirror>) reflectClassWithName: (NSString *)className;
+ (id <ETProtocolMirror>) reflectProtocolWithName: (NSString *)protocolName;
+ (id <ETProtocolMirror>) reflectProtocol: (Protocol *)aProtocol;
@end


