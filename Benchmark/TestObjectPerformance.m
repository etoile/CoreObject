/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"
#import "COContainer.h"
#import "BenchmarkCommon.h"

#define CREATION_ITERATIONS 1000
#define ACCESS_ITERATIONS   100000
#define MODIFICATION_ITERATIONS 1000

#define US_PER_SECOND 1000000

/*
 
 We'll make a really simple object graph like this:
 parent -> child1, child2, child3
 
 */

@interface FoundationModelObject : NSObject
@property (nonatomic, readwrite) NSString *stringProperty;
@property (nonatomic, readwrite) NSMutableArray *arrayProperty;
@end

@implementation FoundationModelObject
@synthesize stringProperty, arrayProperty;
@end


@interface TestObjectPerformance : TestCase <UKTest>
{
	FoundationModelObject *foundationParent;
	FoundationModelObject *foundationChild1;
	FoundationModelObject *foundationChild2;
	FoundationModelObject *foundationChild3;
	
	COObjectGraphContext *objectGraphContext;
	OutlineItem *coreobjectParent;
	OutlineItem *coreobjectChild1;
	OutlineItem *coreobjectChild2;
	OutlineItem *coreobjectChild3;
}
@end

@implementation TestObjectPerformance

- (id)init
{
	SUPERINIT;
	[self createFoundationObjects];
	[self createCoreObjects];
	return self;
}

- (void) createFoundationObjects
{
	foundationParent = [FoundationModelObject new];
	foundationChild1 = [FoundationModelObject new];
	foundationChild2 = [FoundationModelObject new];
	foundationChild3 = [FoundationModelObject new];
	foundationParent.stringProperty = @"parent";
	foundationChild1.stringProperty = @"child1";
	foundationChild2.stringProperty = @"child2";
	foundationChild3.stringProperty = @"child3";
	foundationParent.arrayProperty = [@[foundationChild1, foundationChild2, foundationChild3] mutableCopy];
}

- (void) createCoreObjects
{
	objectGraphContext = [COObjectGraphContext new];
	coreobjectParent = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	coreobjectChild1 = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	coreobjectChild2 = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	coreobjectChild3 = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	coreobjectParent.label = @"parent";
	coreobjectChild1.label = @"child1";
	coreobjectChild2.label = @"child2";
	coreobjectChild3.label = @"child3";
	coreobjectParent.contents = @[coreobjectChild1, coreobjectChild2, coreobjectChild3];
}

#pragma mark - macros

#define TIME_METHOD(name, iterations, expression) \
- (NSTimeInterval) name \
{ \
	NSDate *start = [NSDate date]; \
	for (int i=0; i<(iterations); i++) \
	{ \
		expression; \
	} \
	return [[NSDate date] timeIntervalSinceDate: start] / iterations; \
}

#define TIME_METHOD_WITH_EXPECTED_RESULT(name, iterations, expression, expected) \
- (NSTimeInterval) name \
{ \
	NSDate *start = [NSDate date]; \
	id result = nil; \
	for (int i=0; i<(iterations); i++) \
	{ \
		result = (expression); \
	} \
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / iterations; \
	ETAssert([(expected) isEqual: result]); \
	return time; \
}

#pragma mark - object graph access

TIME_METHOD(timeToCreateFoundationObjectGraph, CREATION_ITERATIONS, [self createFoundationObjects]);
TIME_METHOD(timeToCreateCoreObjectGraph, CREATION_ITERATIONS, [self createCoreObjects]);

- (void) testObjectGraphCreationPerformance
{
	NSTimeInterval timeToCreateFoundationObjectGraph = [self timeToCreateFoundationObjectGraph];
	NSTimeInterval timeToCreateCoreObjectGraph = [self timeToCreateCoreObjectGraph];
	
	double coreObjectTimesWorse = timeToCreateCoreObjectGraph / timeToCreateFoundationObjectGraph;
	
	NSLog(@"Foundation object graph took %f us, core object graph took %f us. CO is %f times worse.",
		  timeToCreateFoundationObjectGraph * 1000000,
		  timeToCreateCoreObjectGraph * 1000000,
		  coreObjectTimesWorse);
}

#pragma mark - string property access

TIME_METHOD_WITH_EXPECTED_RESULT(timeToAccessFoundationObjectStringProperty, ACCESS_ITERATIONS, foundationParent.stringProperty, @"parent")
TIME_METHOD_WITH_EXPECTED_RESULT(timeToAccessCoreObjectStringProperty, ACCESS_ITERATIONS, coreobjectParent.label, @"parent")

- (void) testStringPropertyAccess
{
	NSTimeInterval timeToAccessFoundationObjectStringProperty = [self timeToAccessFoundationObjectStringProperty];
	NSTimeInterval timeToAccessCoreObjectStringProperty = [self timeToAccessCoreObjectStringProperty];
	
	double coreObjectTimesWorse = timeToAccessCoreObjectStringProperty / timeToAccessFoundationObjectStringProperty;
	
	NSLog(@"Foundation object graph string property acces took %f us, core object graph string property access took %f us. CO is %f times worse.",
		  timeToAccessFoundationObjectStringProperty * 1000000,
		  timeToAccessCoreObjectStringProperty * 1000000,
		  coreObjectTimesWorse);
}

#pragma mark - ordered relationship access

TIME_METHOD_WITH_EXPECTED_RESULT(timeToAccessFoundationObjectOrderedRelationship,
								 ACCESS_ITERATIONS,
								 foundationParent.arrayProperty,
								 A(foundationChild1, foundationChild2, foundationChild3))

TIME_METHOD_WITH_EXPECTED_RESULT(timeToAccessCoreObjectOrderedRelationship,
								 ACCESS_ITERATIONS,
								 coreobjectParent.contents,
								 A(coreobjectChild1, coreobjectChild2, coreobjectChild3))

- (void) testOrderedRelationshipAccess
{
	NSTimeInterval timeToAccessFoundationObjectOrderedRelationship = [self timeToAccessFoundationObjectOrderedRelationship];
	NSTimeInterval timeToAccessCoreObjectOrderedRelationship = [self timeToAccessCoreObjectOrderedRelationship];
	
	double coreObjectTimesWorse = timeToAccessCoreObjectOrderedRelationship / timeToAccessFoundationObjectOrderedRelationship;
	
	NSLog(@"Foundation object graph ordered relationship acces took %f us, core object graph ordered relationship access took %f us. CO is %f times worse.",
		  timeToAccessFoundationObjectOrderedRelationship * 1000000,
		  timeToAccessCoreObjectOrderedRelationship * 1000000,
		  coreObjectTimesWorse);
}

#pragma mark - relationship modification

- (void) modifyFoundationRelationship
{
	// Move child3 to be a child of child1
	[foundationParent.arrayProperty removeObjectAtIndex: 2];
	[foundationChild1.arrayProperty addObject: foundationChild3];
	
	// Move it back
	[foundationChild1.arrayProperty removeObjectAtIndex: 0];
	[foundationParent.arrayProperty addObject: foundationChild3];
}

- (void) modifyCoreObjectRelationship
{
	// Move child3 to be a child of child1
	[coreobjectChild1 addObject: coreobjectChild3];
	
	// Move it back
	[coreobjectParent addObject: coreobjectChild3];
}

TIME_METHOD(timeToModifyFoundationObjectOrderedRelationship, MODIFICATION_ITERATIONS, [self modifyFoundationRelationship]);
TIME_METHOD(timeToModifyCoreObjectOrderedRelationship, MODIFICATION_ITERATIONS, [self modifyCoreObjectRelationship]);

- (void) testOrderedRelationshipModification
{
	NSTimeInterval timeToModifyFoundationObjectOrderedRelationship = [self timeToModifyFoundationObjectOrderedRelationship];
	NSTimeInterval timeToModifyCoreObjectOrderedRelationship = [self timeToModifyCoreObjectOrderedRelationship];
	
	UKObjectsEqual(A(coreobjectChild1, coreobjectChild2, coreobjectChild3), coreobjectParent.contents);
	UKObjectsEqual(A(foundationChild1, foundationChild2, foundationChild3), foundationParent.arrayProperty);
	
	double coreObjectTimesWorse = timeToModifyCoreObjectOrderedRelationship / timeToModifyFoundationObjectOrderedRelationship;
	
	NSLog(@"Foundation relationship modifications took %f us, core object relationship modification took %f us. CO is %f times worse.",
		  timeToModifyFoundationObjectOrderedRelationship * US_PER_SECOND,
		  timeToModifyCoreObjectOrderedRelationship * US_PER_SECOND,
		  coreObjectTimesWorse);
}

@end

@implementation TestCase (Timing)

#pragma mark - Timing Methods

// TODO: Timing infrastructure earlier in the file, using macros, looks awful.
// Convert to use this.
- (NSTimeInterval) timeBlock: (void (^)())aBlock iterations: (NSUInteger)iterations
{
	NSDate *start = [NSDate date];
	for (NSUInteger i=0; i<iterations; i++)
	{
		aBlock();
	}
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / iterations;
	return time;
}

static const int DEFAULT_ITERATIONS = 1000;

static NSString *FormatTimeInterval(NSTimeInterval s)
{
	double us = s * US_PER_SECOND;
	double ms = s * 1000.0;
	if (ms > 1000)
		return [NSString stringWithFormat: @"%f s", s];
	else if (us > 1000)
		return [NSString stringWithFormat: @"%f ms", ms];
	else
		return [NSString stringWithFormat: @"%f us", us];
}

- (void) timeBlock: (void (^)())aBlock iterations: (NSUInteger)iterations message: (NSString *)message
{
	NSTimeInterval time = [self timeBlock: aBlock iterations: iterations];
	NSLog(@"%@ per iteration for '%@'", FormatTimeInterval(time), message);
}


- (void) timeBlock: (void (^)())aBlock message: (NSString *)message
{
	[self timeBlock: aBlock iterations:DEFAULT_ITERATIONS message: message];
}

@end

#pragma mark - Test large relationships

@interface TestLargeOrderedRelationsip : TestCase <UKTest>
{
	COObjectGraphContext *objectGraphContext;
	OutlineItem *coreobjectParent;
}
@end

@implementation TestLargeOrderedRelationsip

- (id)init
{
	SUPERINIT;
	objectGraphContext = [COObjectGraphContext new];
	coreobjectParent = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	return self;
}

static const int LARGE_RELATIONSHIP_SIZE = 1000;

// 2015-09-04: Typewriter performance is getting unusably slow on small documents

- (void) testCreateLargeOrderedRelationsip
{
	// compare speed of COObject's -addObject: with NSMutableArray's
	NSMutableArray *items = [NSMutableArray new];
	__block int i = 0;
	[self timeBlock: ^(void) {
		OutlineItem *child = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
		child.label = [NSString stringWithFormat: @"%d", i++];
		[items addObject: child];
	} iterations: LARGE_RELATIONSHIP_SIZE message: @"Create OutlineItem and add to an NSMutableArray with -addObject:"];
	
	// compare speed of COObject's -addObject: with NSMutableArray's
	i = 0;
	[self timeBlock: ^(void) {
		OutlineItem *child = items[i++];
		[coreobjectParent addObject: child];
	} iterations: LARGE_RELATIONSHIP_SIZE message: @"Add OutlineItem to an OutlineItem with -addObject:"];

	NSMutableArray *nsmutablearray = [NSMutableArray new];
	i = 0;
	[self timeBlock: ^(void) {
		OutlineItem *child = items[i++];
		[nsmutablearray addObject: child];
	} iterations: LARGE_RELATIONSHIP_SIZE message: @"Add OutlineItem to an NSMutableArray with -addObject:"];
	
	// test -count
	
	NSArray *parentContentsArray = coreobjectParent.contents;
	__block NSUInteger count = 0;
	[self timeBlock: ^(void) {
		count += [parentContentsArray count];
	} message: [NSString stringWithFormat: @"-count on CoreObject array with %d elements", LARGE_RELATIONSHIP_SIZE]];
	
	NSArray *parentContentsArrayCopy = [NSArray arrayWithArray: coreobjectParent.contents];
	[self timeBlock: ^(void) {
		count += [parentContentsArrayCopy count];
	} message: [NSString stringWithFormat: @"-count on NSArray with %d elements", LARGE_RELATIONSHIP_SIZE]];
	
	// test for/in loop
	
	[self timeBlock: ^(void) {
		for (OutlineItem *child in parentContentsArray)
		{
			count += (intptr_t)(child);
		}
	} message: [NSString stringWithFormat: @"for/in loop on CoreObject array with %d elements", LARGE_RELATIONSHIP_SIZE]];
	
	[self timeBlock: ^(void) {
		for (OutlineItem *child in parentContentsArrayCopy)
		{
			count += (intptr_t)(child);
		}
	} message: [NSString stringWithFormat: @"for/in loop on NSArray with %d elements", LARGE_RELATIONSHIP_SIZE]];
}


@end
