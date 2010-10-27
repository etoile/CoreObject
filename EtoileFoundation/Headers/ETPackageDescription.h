/** <title>ETModelDescriptionPackage</title>

	<abstract>A model description framework inspired by FAME 
	(http://scg.unibe.ch/wiki/projects/fame)</abstract>
 
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2010
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelElementDescription.h>
#import <EtoileFoundation/ETCollection.h>

@class ETEntityDescription, ETPropertyDescription;

/** Collection of related entity descriptions, usually equivalent to a data model.

A package can also include extensions to other entity descriptions. An extension 
is a property description whose owner doesn't belong to the package it gets 
added to.<br />
For example, a category can be described with a property description array, and 
these property descriptions packaged as extensions to be resolved later (usually 
when the package is imported/deserialized).

From a Model Builder perspective, a package is the document you work on to 
specify a data model.  */
@interface ETPackageDescription : ETModelElementDescription <ETCollection>
{
	NSMutableSet *_entityDescriptions;
	NSMutableSet *_propertyDescriptions;
}

/** Self-description (aka meta-metamodel). */
+ (ETEntityDescription *) newEntityDescription;

/** Returns YES. */
- (BOOL) isPackageDescription;
/** Returns 'Package'. */
- (NSString *) typeDescription;

/** Adds the given entity to the package, the package becomes its owner.

Will remove every property from the package that extends this entity and 
previously added with -addPropertyDescription: or -setPropertyDescriptions:. */
- (void) addEntityDescription: (ETEntityDescription *)anEntityDescription;
/** Removes the given entity from the package. */
- (void) removeEntityDescription: (ETEntityDescription *)anEntityDescription;
/** Replaces the entities in the package with the given ones. */
- (void) setEntityDescriptions: (NSSet *)entityDescriptions;
/** Returns the entities that belong to the package.

The returned collection is an autoreleased copy. */
- (NSSet *) entityDescriptions;

/** Adds the given entity extension to the package.

The property owner must be the entity to be extended.<br />
Raises an NSInvalidArgumentException when the property owner is nil or already 
belongs to the package. */
- (void) addPropertyDescription: (ETPropertyDescription *)propertyDescription;
/** Removes the given entity extension from the package. */
- (void) removePropertyDescription: (ETPropertyDescription *)propertyDescription;
/** Replaces the entity extensions in the package by the given ones. */
- (void) setPropertyDescriptions: (NSSet *)propertyDescriptions;
/** Returns the entity extensions that belong to the package.

The returned collection is an autoreleased copy. */
- (NSSet *) propertyDescriptions;

/* Runtime Consistency Check */

/** Checks the receiver conforms to the FM3 constraint spec and adds a short 
warning to the given array for each failure. */
- (void) checkConstraints: (NSMutableArray *)warnings;

@end
