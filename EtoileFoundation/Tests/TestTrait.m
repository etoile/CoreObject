#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSObject+Trait.h"
#import "ETCollection.h"
#import "Macros.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@interface TestBasicTrait : NSObject <UKTest>
@end

@interface TestComplexTrait : NSObject <UKTest>
@end

@interface TestTraitExclusionAndAliasing : NSObject <UKTest>
@end

@interface TestTraitSequence : NSObject <UKTest>
@end

@interface TestBasicCompositeTrait : NSObject <UKTest>
@end

@interface TestRedundantSubtraitInheritance : NSObject <UKTest>
@end

@interface TestTraitMethodConflictAndOverridingRule : NSObject <UKTest>
@end

@interface TestMixinStyleComposition : NSObject <UKTest>
@end

@interface TestBasicTrait (BasicTrait)
- (void) bip;
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (BOOL) isOrdered;
@end

@interface TestComplexTrait (ComplexTrait)
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (BOOL) isOrdered;
- (int) intValue;
@end

@interface TestTraitExclusionAndAliasing (BasicTrait)
- (void) bip;
- (NSString *) lost: (NSUInteger)aLocation;
@end

@interface TestTraitSequence (BasicAndComplexTrait)
- (void) bip;
- (NSString *) lost: (NSUInteger)aLocation;
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (BOOL) isOrdered;
- (int) intValue;
@end

@interface TestBasicCompositeTrait (BasicAndComplexTrait)
- (void) bip;
- (NSString *) lost: (NSUInteger)aLocation;
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (BOOL) isOrdered;
- (int) intValue;
@end

@interface TestRedundantSubtraitInheritance (Subtrait)
- (NSString *) name;
@end

@interface TestTraitMethodConflictAndOverridingRule (BasicAndComplexTrait)
- (NSString *) wanderWhere: (NSUInteger)aLocation;
@end

@interface TestMixinStyleComposition (BasicAndComplexTrait)
- (BOOL) isOrdered;
- (NSString *) lost: (NSUInteger)aLocation;
- (int) intValue;
@end

/* Trait Declarations */

@interface BasicTrait : NSObject
- (void) bip;
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (BOOL) isOrdered;
@end

@interface ComplexTrait : BasicTrait
- (NSString *) wanderWhere: (NSUInteger)aLocation;
- (int) intValue;
@end

@interface CompositeTrait : NSObject
- (NSString *) hello;
@end

@interface Trait1 : NSObject
@end

@interface Trait2 : NSObject
@end

@interface Subtrait : NSObject
- (NSString *) name;
@end

/* Methods to be provided by the target class or subtraits */
@interface CompositeTrait (RequiredMethods)
- (NSString *) wanderWhere: (NSUInteger)aLocation;
@end

/* Test Suite */

@implementation TestBasicTrait

- (BOOL) isOrdered
{
	return YES;
}

- (void) testApplyTrait
{
	[[self class] applyTraitFromClass: [BasicTrait class]];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKStringsEqual(@"Nowhere", [self wanderWhere: 5]);
	UKTrue([self isOrdered]);
}

@end

@implementation TestComplexTrait

- (BOOL) isOrdered
{
	return YES;
}

- (void) testApplyTrait
{
	[[self class] applyTraitFromClass: [ComplexTrait class]];

	UKFalse([self respondsToSelector: @selector(bip)]);
	UKStringsEqual(@"Somewhere", [self wanderWhere: 5]);
	UKTrue([self isOrdered]);
	UKIntsEqual(3, [self intValue]);	
}

@end

@implementation TestTraitExclusionAndAliasing

- (void) testApplyTrait
{
	[[self class] applyTraitFromClass: [BasicTrait class]
	              excludedMethodNames: S(@"isOrdered")
	               aliasedMethodNames: D(@"lost:", @"wanderWhere:")];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKTrue([self respondsToSelector: @selector(lost:)]);
	UKFalse([self respondsToSelector: @selector(wanderWhere:)]);
	UKStringsEqual(@"Nowhere", [self lost: 5]);
	UKFalse([self respondsToSelector: @selector(isOrdered)]);
}

@end

@implementation TestTraitSequence

- (void) testApplyTrait
{
	[[self class] applyTraitFromClass: [BasicTrait class]
	              excludedMethodNames: S(@"isOrdered")
	               aliasedMethodNames: D(@"lost:", @"wanderWhere:")];
	[[self class] applyTraitFromClass: [ComplexTrait class]];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKTrue([self respondsToSelector: @selector(lost:)]);
	UKStringsEqual(@"Nowhere", [self lost: 5]);
	UKTrue([self respondsToSelector: @selector(wanderWhere:)]);
	UKStringsEqual(@"Somewhere", [self wanderWhere: 5]);
	UKFalse([self respondsToSelector: @selector(isOrdered)]);
	UKIntsEqual(3, [self intValue]);
}

@end

@implementation TestBasicCompositeTrait

- (void) testApplyTrait
{
	[[CompositeTrait class] applyTraitFromClass: [BasicTrait class]
	                        excludedMethodNames: S(@"isOrdered")
	                         aliasedMethodNames: D(@"lost:", @"wanderWhere:")];
	[[CompositeTrait class] applyTraitFromClass: [ComplexTrait class]];

	[[self class] applyTraitFromClass: [CompositeTrait class]];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKTrue([self respondsToSelector: @selector(lost:)]);
	UKStringsEqual(@"Nowhere", [self lost: 5]);
	UKTrue([self respondsToSelector: @selector(wanderWhere:)]);
	UKStringsEqual(@"Somewhere", [self wanderWhere: 5]);
	UKFalse([self respondsToSelector: @selector(isOrdered)]);
	UKIntsEqual(3, [self intValue]);
}

@end

@implementation TestRedundantSubtraitInheritance

- (void) testApplyTrait
{
	[[Trait1 class] applyTraitFromClass: [Subtrait class]];
	[[Trait2 class] applyTraitFromClass: [Subtrait class]];
	
	[[self class] applyTraitFromClass: [Trait2 class]];
	[[self class] applyTraitFromClass: [Trait1 class]];

	UKStringsEqual(@"Mike", [self name]);
}

@end

@implementation TestTraitMethodConflictAndOverridingRule

- (NSString *) wanderWhere: (NSUInteger)aLocation
{
	return @"Anywhere";
}

- (void) testApplyTrait
{	
	[[self class] applyTraitFromClass: [BasicTrait class]];
	// Although both trait classes implement -wanderWhere:, no exception 
	// should be raised, because the target class implements its own 
	// -wanderWhere: version.
	[[self class] applyTraitFromClass: [ComplexTrait class]];

	UKStringsEqual(@"Anywhere", [self wanderWhere: 9]);
}

@end

@implementation TestMixinStyleComposition

- (BOOL) isOrdered
{
	return YES;
}

- (NSString *) lost: (NSUInteger)aLocation
{
	return @"Anywhere";
}

- (int) intValue 
{
	return 100; 
}

- (void) testApplyTrait
{
	[[self class] applyTraitFromClass: [BasicTrait class]
	              excludedMethodNames: S(@"isOrdered")
	               aliasedMethodNames: D(@"lost:", @"wanderWhere:")
	                   allowsOverride: YES];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKTrue([self respondsToSelector: @selector(lost:)]);
	UKFalse([self respondsToSelector: @selector(wanderWhere:)]);
	UKStringsEqual(@"Nowhere", [self lost: 5]);
	UKTrue([self isOrdered]);

	[[self class] applyTraitFromClass: [ComplexTrait class]
	              excludedMethodNames: [NSSet set]
	               aliasedMethodNames: D(@"lost:", @"wanderWhere:")
	                   allowsOverride: YES];

	UKTrue([self respondsToSelector: @selector(bip)]);
	UKTrue([self respondsToSelector: @selector(lost:)]);
	UKFalse([self respondsToSelector: @selector(wanderWhere:)]);
	UKStringsEqual(@"Somewhere", [self lost: 5]);
	UKTrue([self isOrdered]);
	UKIntsEqual(3, [self intValue]);
}

@end

/* Trait Implementations */

@implementation BasicTrait
- (void) bip { }
- (NSString *) wanderWhere: (NSUInteger)aLocation { return @"Nowhere"; }
- (BOOL) isOrdered { return NO; }
@end

@implementation ComplexTrait
- (NSString *) wanderWhere: (NSUInteger)aLocation { return @"Somewhere"; }
- (int) intValue { return 3; };
@end

@implementation CompositeTrait
- (NSString *) hello { return [self wanderWhere: 0]; }
@end

@implementation Trait1
@end

@implementation Trait2
@end

@implementation Subtrait
- (NSString *) name { return @"Mike"; }
@end
