/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  July 2014
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * This is meant to be a spec for corner cases in the metamodel;
 */
@interface TestMetamodelCornerCases : EditingContextTestCase <UKTest>
@end


@implementation TestMetamodelCornerCases

/**
 * do we support both aggregate and composite references (EMOF) or just
 * composite (FM3)?
 */
- (void) testNoAggregate
{
	// Following FM3, we don't support aggregate as a separate case
	
	// The only point of supporting aggregate as a distinct concept from composite
	// would be to model relationships where a child can be in two containers
	// at once, but the relationship forbids cycles. This could maybe be
	// desirable for some kind of relationship representing tagging, but
	// until there's a concrete use case we're not supporting it.
	
	ETPropertyDescription *testProp = [ETPropertyDescription descriptionWithName: @"contents"
																			type: (id)@"Anonymous.COObject"];
	UKFalse([testProp respondsToSelector: @selector(setAggregate:)]);
}

#pragma mark -

- (ETEntityDescription *)nonCompositeOneToManyWithOppositeEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"NonCompositeOneToManyWithOpposite"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.NonCompositeOneToManyWithOpposite"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
	[contentsProperty setOpposite: (id)@"Anonymous.NonCompositeOneToManyWithOpposite.parent"];
	
	ETPropertyDescription *parentProperty = [ETPropertyDescription descriptionWithName: @"parent"
																				  type: (id)@"Anonymous.NonCompositeOneToManyWithOpposite"];
    [parentProperty setMultivalued: NO];
	[parentProperty setOpposite: (id)@"Anonymous.NonCompositeOneToManyWithOpposite.contents"];
	[parentProperty setDerived: YES];
	
	[entity setPropertyDescriptions: @[contentsProperty, parentProperty]];
	
    return entity;
}

/**
 * do we support one:many relationships with opposite that are not composite?
 */
- (void) testOneToManyWithOppositeNotComposite
{
	ETEntityDescription *entity = [self nonCompositeOneToManyWithOppositeEntityDescription];
	
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
	[repo addUnresolvedDescription: entity];
	[repo resolveNamedObjectReferences];

	UKFalse([[entity propertyDescriptionForName: @"contents"] isComposite]);
	UKFalse([[entity propertyDescriptionForName: @"parent"] isContainer]);
	
	COObjectGraphContext *graph = [COObjectGraphContext new];
	COObject *a = [graph insertObjectWithEntityName: @"NonCompositeOneToManyWithOpposite"];
	COObject *b = [graph insertObjectWithEntityName: @"NonCompositeOneToManyWithOpposite"];
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithRootObject: a];
	
	[a setValue: S(a, b) forProperty: @"contents"];
	
	UKTrue([ctx commit]);
}



/*
 *  - do we support unidirectional aggregate / composites references?
 *  - is more than one "container" property per class permitted (EMOF) or not (FM3)?
 *    - if yes, do we correctly enforce the constraint at runtime that only one
 *      can be non-nil?
 *  - do we support multiple inheritance? (e.g. so ETLayoutItemGroup can
 *    inherit from both ETLayoutItem and COContainer)
 *  - how to handle an object like OutlineItem whose container can be either
 *    an OutlineItem or Document?
 */

@end
