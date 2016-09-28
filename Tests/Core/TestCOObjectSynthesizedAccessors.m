/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

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

- (id)init
{
    SUPERINIT;
    item = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    return self;
}

- (void)testAttributeGetterAndSetter
{

    UKObjectKindOf(item, OutlineItem);

    item.label = @"hello";
    UKObjectsEqual(@"hello", item.label);

    OutlineItem *child1 = [item.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    child1.label = @"child1";

    OutlineItem *child2 = [item.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    child2.label = @"child2";

    [item setContents: @[child1, child2]];
    UKObjectsEqual(A(child1, child2), item.contents);
}

- (void)testSynthesizedAccessorsRestrictedToDynamicProperties
{
    UKRaisesException([item unkownMethod]);

    NSAssert([[item.entityDescription propertyDescriptionForName: @"isPersistent"] isReadOnly],
             @"We expect isPersistent to be read-only for COObject and its subclasses");
    UKRaisesException([(id)item setIsPersistent: YES]);
}

- (void)testMutableProxy
{
    OutlineItem *child1 = [item.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];

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
    UKObjectsEqual(@[child1], item.contents);

    [[item mutableArrayValueForKey: @"contents"] removeObject: child1];
    UKObjectsEqual(@[], item.contents);
}

- (void)testSetterToProperty
{
    const char *setter = "setFoo:";
    char *property = malloc(strlen(setter) - 3);
    SetterToProperty(setter, strlen(setter), property);

    UKIntsEqual(0, strcmp("foo", property));
    free(property);
}

static BOOL IsSetterWrapper(const char *selname)
{
    return IsSetter(selname, strlen(selname));
}

- (void)testIsSetter
{
    UKTrue(IsSetterWrapper("setFoo:"));
    UKTrue(IsSetterWrapper("seta:"));

    UKFalse(IsSetterWrapper("set:"));
    UKFalse(IsSetterWrapper("setFoo"));
    UKFalse(IsSetterWrapper("foo:"));
    UKFalse(IsSetterWrapper(""));
}

@end
