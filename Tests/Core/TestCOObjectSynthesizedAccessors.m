/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>,
             Quentin Mathe <quentin.mathe@gmail.com>
    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface NSObject (TestObjectSynthesizedAccessors)
- (id)unkownMethod;
- (void)setIsPersistent: (BOOL)persistent;
- (NSString *)something;
@end

@interface TestCOObjectSynthesizedAccessors : EditingContextTestCase <UKTest>
{
	OutlineItem *item;
}
@end

@implementation TestCOObjectSynthesizedAccessors

- (id) init
{
    SUPERINIT;
    item = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
    return self;
}

- (void) testAttributeGetterAndSetter
{

    UKObjectKindOf(item, OutlineItem);
    
    [item setLabel: @"hello"];
    UKObjectsEqual(@"hello", [item label]);
    
    OutlineItem *child1 = [[item objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [child1 setLabel: @"child1"];

    OutlineItem *child2 = [[item objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [child2 setLabel: @"child2"];

    [item setContents: A(child1, child2)];
    UKObjectsEqual(A(child1, child2), [item contents]);
}

- (void)addPropertyDescriptionToOutlineItem
{
	ETAssert([[item entityDescription] propertyDescriptionForName: @"something"] == nil);
	ETEntityDescription *type = [[ctx modelDescriptionRepository] entityDescriptionForClass: [NSString class]];
	ETPropertyDescription *propertyDesc = [ETPropertyDescription descriptionWithName: @"something" type: type];

	[[item entityDescription] addPropertyDescription: propertyDesc];

	ETAssert([propertyDesc isReadOnly] == NO);
}

- (void)removePropertyDescriptionFromOutlineItem
{
	ETPropertyDescription *propertyDesc = [[item entityDescription] propertyDescriptionForName: @"something"];
	[[item entityDescription] removePropertyDescription: propertyDesc];
}

- (void)testSynthesizedAccessorsRestrictedToDynamicProperties
{
	UKRaisesException([item unkownMethod]);

	[self addPropertyDescriptionToOutlineItem];

	UKNil([item valueForProperty: @"something"]);
	UKRaisesException([item something]);

	[self removePropertyDescriptionFromOutlineItem];

	NSAssert([[[item entityDescription] propertyDescriptionForName: @"isPersistent"] isReadOnly],
		@"We expect isPersistent to be read-only for COObject and its subclasses");
	UKRaisesException([(id)item setIsPersistent: YES]);
}

- (void) testMutableProxy
{
    OutlineItem *child1 = [[item objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
    // At first I didn't think this would work right now, but
    // when -mutableArrayValueForKey: does its accessor search, it causes
    // +resolveInstanceMethod: to be invoked, which lets us auto-generate
    // acecssors.
    //
    // Currently we only generate -XXX and -setXXX:, but that's sufficient
    // for -mutableArrayValueForKey: to work. We will need to add support
    // for generating the indexed ones for good performance, though.
    
    // FIXME: Change to mutableOrderedSetValueForKey
    [[item mutableArrayValueForKey: @"contents"] addObject: child1];
    UKObjectsEqual(@[child1], [item contents]);

    [[item mutableArrayValueForKey: @"contents"] removeObject: child1];
    UKObjectsEqual(@[], [item contents]);
}

@end
