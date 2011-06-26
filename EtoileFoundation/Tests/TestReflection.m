#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/EtoileFoundation.h>

/* Classes we use to test reflection */

@interface TestClass1 : NSObject <NSCopying>
{
	int ivar1;
}
- (id)copyWithZone: (NSZone *)zone;
@end
@implementation TestClass1
- (id)copyWithZone: (NSZone *)zone
{
	return nil;
}
@end

@interface TestClass2 : TestClass1
{
	int ivar2;
}
- (void)foo;
@end
@implementation TestClass2
- (void)foo
{
	;
}
@end



@interface TestReflection : NSObject <UKTest>
{
}
@end

@implementation TestReflection

- (void) testBasic
{
	id objMirror = [ETReflection reflectObject: [[NSObject alloc] init]];
	
	UKStringsEqual([[objMirror classMirror] name], @"NSObject");
	
	UKNil([[objMirror classMirror] superclassMirror]);
	
	/**
	 * Test that subclassMirrors/allSubclassMirrors works (roughly).
	 * Also test that two different class mirrors on the same class compare
	 * as equal.
	 */
	UKTrue([[[objMirror classMirror] allSubclassMirrors] containsObject:
			[ETReflection reflectClass: [NSMutableDictionary class]]]);
	
	UKFalse([[[objMirror classMirror] subclassMirrors] containsObject:
			[ETReflection reflectClass: [NSMutableDictionary class]]]);

	UKTrue([[[objMirror classMirror] subclassMirrors] containsObject:
			[ETReflection reflectClassWithName: @"NSDictionary"]]);
}

- (void) testProtocolInheritance
{
	id classMirror1 = [ETReflection reflectClassWithName: @"TestClass1"];
	id classMirror2 = [ETReflection reflectClassWithName: @"TestClass2"];

	UKTrue([[classMirror1 adoptedProtocolMirrors] containsObject:
		[ETReflection reflectProtocolWithName: @"NSCopying"]]);

	UKObjectsEqual([NSArray array],
		[classMirror2 adoptedProtocolMirrors]);

	UKTrue([[classMirror2 allAdoptedProtocolMirrors] containsObject:
		[ETReflection reflectProtocolWithName: @"NSObject"]]);
	UKTrue([[classMirror2 allAdoptedProtocolMirrors] containsObject:
		[ETReflection reflectProtocolWithName: @"NSCopying"]]);
}

- (void) testMetaClass
{
	UKFalse([[ETReflection reflectClass: [NSObject class]] isMetaClass]);
	UKTrue([[[ETReflection reflectObject: [NSObject class]] classMirror] isMetaClass]);
}

- (void) testBadValues
{
#if 0
	UKNil([ETReflection reflectClassWithName: @"ThisClassDoesNotExist"]);
	UKNil([ETReflection reflectProtocolWithName: @"ThisProtocolDoesNotExist"]);
#endif
	UKNil([ETReflection reflectObject: nil]);
	UKNil([ETReflection reflectClass: Nil]);
}

- (void) testIVars
{
	id test2 = [ETReflection reflectClass: [TestClass2 class]];
	
	UKStringsEqual(@"ivar2", [[[test2 instanceVariableMirrors] objectAtIndex: 0] name]);
	UKIntsEqual(1, [[test2 instanceVariableMirrors] count]);
	UKTrue([[test2 allInstanceVariableMirrors] count] > 2);
}

- (void) testMethods
{
	id test2 = [ETReflection reflectClass: [TestClass2 class]];
	
	UKStringsEqual(@"foo", [[[test2 methodMirrors] objectAtIndex: 0] name]);
	UKIntsEqual(1, [[test2 methodMirrors] count]);

	UKTrue([[test2 allMethodMirrors] count] > 10);

}

@end
