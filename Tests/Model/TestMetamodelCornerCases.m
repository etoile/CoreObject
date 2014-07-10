/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  July 2014
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * This is meant to be a spec for corner cases in the metamodel.
 */
@interface TestMetamodelCornerCases : EditingContextTestCase <UKTest>
@end


@implementation TestMetamodelCornerCases

/**
 * Q: do we support both aggregate and composite references (EMOF) or just
 *    composite (FM3)?
 *
 * A: Following FM3's design, we don't support aggregate as a separate case.
 *    The only point of supporting aggregate as a distinct concept from composite
 *    would be to model relationships where a child can be in two containers
 *    at once, but the relationship forbids cycles. This could maybe be
 *    desirable for some kind of relationship representing tagging, but
 *    until there's a concrete use case we're not supporting it.
 *
 *    Quentin: I would say that documenting/encoding a relationship as an 
 *    aggregation doesn't matter for ownership. As a result, it doesn't impact 
 *    the lifetime of the aggregated object and how it gets copied across object
 *    graphs. So aggregation is useful to understand the relationships between 
 *    the objects but doesn't matter from an implementation/behavior perspective.
 *    While composite matters from an implementation/behavior perspective.
 */
- (void) testNoAggregate
{
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
 * Q: do we support one:many relationships with opposite that are not composite?
 *
 * A: No, currently one:many relationships with opposite are automatically composite in CO.
 *    Both FM3 and EMOF do support it, but we can't think of a use case. The use case
 *    would have to involve a one:many where you _don't_ want the composite 
 *    constraints (all composite relationships form a DAG, only one container
 *    property is non-null per object)
 */
- (void) testOneToManyWithOppositeNotComposite
{
	ETEntityDescription *entity = [self nonCompositeOneToManyWithOppositeEntityDescription];
	
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
	[repo addUnresolvedDescription: entity];
	[repo resolveNamedObjectReferences];

	UKTrue([[entity propertyDescriptionForName: @"contents"] isComposite]);
	UKTrue([[entity propertyDescriptionForName: @"parent"] isContainer]);
}


/**
 * Q: do we support unidirectional aggregate / composites references?
 *
 * A: No. FM3 also doesn't support unidirectional composites, not sure about EMOF.
 *    Don't have a compelling use case in mind, so it's probably not worth the effort.
 */
- (void) testUnidirectionalCompositeUnsupported
{
	
}

/**
 * Q: is more than one "container" property per class permitted (EMOF) or not 
 *    (FM3)?. if more than one "container" property per class permitted, do we
 *    correctly enforce the constraint at runtime that only one can be non-nil?
 *
 * A: Currently, not sure, it's probably permitted. IMO the FM3 design is cleaner,
 *    and we should move to using that constraint.
 *
 *    Quentin: if we support multiple inheritance, I'm fine with the FM3
 *    approach, otherwise we should stick to EMOF.
 */
- (void) testOnlyOneContainerPropertyAllowed
{
	
}

/**
 * Q: do we support multiple inheritance? (e.g. so ETLayoutItemGroup can 
 *    inherit from both ETLayoutItem and COContainer)
 *    If not, how to handle an object like OutlineItem whose container can be 
 *    either an OutlineItem or Document?
 *
 * A: We probably should.
 */
- (void) testMultipleInheritance
{
	
}

@end
