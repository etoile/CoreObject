/** <title>ETModelDescriptionRepository</title>

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

@class ETModelElementDescription, ETEntityDescription, ETPackageDescription, 
	ETPropertyDescription;

/** Repository used to store the entity descriptions at runtime.

Each repository manages a closed model description graph. Model element 
descriptions present in a repository must only reference objects that belong to 
the same repository.

The repository resolves references to other element descriptions and checks the 
model description graph consistency, every time entity or package descriptions 
are added to it.

A main repository is created in every tool or application at launch time. 
Additional repositories can be created. For example, to store variations on the 
main repository data model.  */
@interface ETModelDescriptionRepository : NSObject <ETCollection>
{
	NSMutableSet *_unresolvedDescriptions; /* Used to build the repository */
	NSMutableDictionary *_descriptionsByName; /* Descriptions registered in the repositiory */
	NSMapTable *_entityDescriptionsByClass;
	NSMapTable *_entityDescriptionsByObject;
}

/** Returns the initial repository that exists in each process.

When this repository is created, existing entity descriptions are collected 
by invoking +newEntityDescription on every NSObject subclass and bound to the 
class that provided the description. See -setEntityDescription:forClass:. */
+ (id) mainRepository;

/** Self-description (aka meta-metamodel). */
+ (ETEntityDescription *) newEntityDescription;
/** Traverses the class hierarchy downwards to collect the entity descriptions 
by invoking +newEntityDescription on each class (including the given class) and 
bind each entity description to the class that provided it. 
See -setEntityDescription:forClass:. 

If resolve is YES, the named references that exists between the descriptions 
are resolved immediately with -resolveNamedObjectReferences. Otherwise they 
are not and the repository remain in an invalid state until 
-resolveNamedObjectReferences is called. */
- (void) collectEntityDescriptionsFromClass: (Class)aClass 
                            excludedClasses: (NSSet *)excludedClasses 
                                 resolveNow: (BOOL)resolve;

/* Registering and Enumerating Descriptions */

/** Returns the default package to which entity descriptions are added when 
they have none and they get put in the repository.

e.g. NSObject will have the returned package as its owner when its entity 
description is automatically registered in the main repository.

See also -addDescription:. */
- (ETPackageDescription *) anonymousPackageDescription;

/** Adds the given package, entity or property description to the repository.

Full names are allowed as late-bound descriptions references in the description 
properties listed below:
<list>
<item>owner</item>
<item>package</item>
<item>parent</item>
<item>opposite</item>
</list>
For example, [anEntityDesc setParent: @"MyPackage.MySuperEntity"] or 
[aPropertyDesc setOpposite: @"MyPackage.MyEntity.whatever"].

Once all the descriptions (unresolved or not) are registered to ensure a valid 
repository state, if any unresolved description was added, you must call 
-resolveNamedObjectReferences on the repository before using it or any 
registered description. */
- (void) addUnresolvedDescription: (ETModelElementDescription *)aDescription;
/** Adds the given package, entity or property description to the repository.

If the given description is an entity description whose owner is nil, 
-anonymousPackageDescription becomes its owner, and it gets registered under 
the full name 'Anonymous.MyEntityName'. */
- (void) addDescription: (ETModelElementDescription *)aDescription;
/** Removes the given package, entity or property description from the repository. */
- (void) removeDescription: (ETModelElementDescription *)aDescription;
/** Returns the packages registered in the repository.

The returned collection is an autoreleased copy. */
- (NSArray *) packageDescriptions;
/** Returns the entity descriptions registered in the repository.

The returned collection is an autoreleased copy. */
- (NSArray *) entityDescriptions;
/** Returns the property description registered in the repository.

The returned collection is an autoreleased copy. */
- (NSArray *) propertyDescriptions;
/** Returns all the package, entity and property descriptions registered in the 
repository.

The returned collection is an autoreleased copy. */
- (NSArray *) allDescriptions;
/** Returns a package, entity or property description registered for the given 
full name.<br />
e.g. 'Anonymous.NSObject' for NSObject entity */
- (id) descriptionForName: (NSString *)aFullName;


/* Binding Descriptions to Class Instances and Prototypes */

- (ETEntityDescription *) entityDescriptionForClass: (Class)aClass;
- (void) setEntityDescription: (ETEntityDescription *)anEntityDescription
                     forClass: (Class)aClass;

/* Resolving References Between Entity Descriptions */

- (void) resolveNamedObjectReferences;

/* Runtime Consistency Check */

/** Checks the receiver content conforms to the FM3 constraint spec and adds a short 
warning to the given array for each failure. */
- (void) checkConstraints: (NSMutableArray *)warnings;

@end
