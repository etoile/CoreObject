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
#define ACCESS_ITERATIONS   1000000

/*
 
 We'll make a really simple object graph like this:
 parent -> child1, child2, child3
 
 */

@interface FoundationModelObject : NSObject
@property (nonatomic, readwrite) NSString *stringProperty;
@property (nonatomic, readwrite) NSArray *arrayProperty;
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
	foundationParent.arrayProperty = @[foundationChild1, foundationChild2, foundationChild3];
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

#pragma mark - object graph access

- (NSTimeInterval) timeToCreateFoundationObjectGraph
{
	NSDate *start = [NSDate date];
	for (int i=0; i<CREATION_ITERATIONS; i++)
	{
		[self createFoundationObjects];
	}
	return [[NSDate date] timeIntervalSinceDate: start] / CREATION_ITERATIONS;
}

- (NSTimeInterval) timeToCreateCoreObjectGraph
{
	NSDate *start = [NSDate date];
	for (int i=0; i<CREATION_ITERATIONS; i++)
	{
		[self createCoreObjects];
	}
	return [[NSDate date] timeIntervalSinceDate: start] / CREATION_ITERATIONS;
}

- (void) testObjectGraphCreationPerformance
{
	NSTimeInterval timeToCreateFoundationObjectGraph = [self timeToCreateFoundationObjectGraph];
	NSTimeInterval timeToCreateCoreObjectGraph = [self timeToCreateCoreObjectGraph];
	
	double coreObjectTimesWorse = timeToCreateCoreObjectGraph / timeToCreateFoundationObjectGraph;
	
	NSLog(@"Foundation object graph took %f us, core object graph took %f us. CO is %f times wrose.",
		  timeToCreateFoundationObjectGraph * 1000000,
		  timeToCreateCoreObjectGraph * 1000000,
		  coreObjectTimesWorse);
}

#pragma mark - string property access

- (NSTimeInterval) timeToAccessFoundationObjectStringProperty
{
	id value = nil;
	NSDate *start = [NSDate date];
	for (int i=0; i<ACCESS_ITERATIONS; i++)
	{
		value = foundationParent.stringProperty;
	}
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / ACCESS_ITERATIONS;
	ETAssert([value isEqualToString: @"parent"]);
	return time;
}

- (NSTimeInterval) timeToAccessCoreObjectStringProperty
{
	id value = nil;
	NSDate *start = [NSDate date];
	for (int i=0; i<ACCESS_ITERATIONS; i++)
	{
		value = coreobjectParent.label;
	}
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / ACCESS_ITERATIONS;
	ETAssert([value isEqualToString: @"parent"]);
	return time;
}

- (void) testStringPropertyAccess
{
	NSTimeInterval timeToAccessFoundationObjectStringProperty = [self timeToAccessFoundationObjectStringProperty];
	NSTimeInterval timeToAccessCoreObjectStringProperty = [self timeToAccessCoreObjectStringProperty];
	
	double coreObjectTimesWorse = timeToAccessCoreObjectStringProperty / timeToAccessFoundationObjectStringProperty;
	
	NSLog(@"Foundation object graph string property acces took %f us, core object graph string property access took %f us. CO is %f times wrose.",
		  timeToAccessFoundationObjectStringProperty * 1000000,
		  timeToAccessCoreObjectStringProperty * 1000000,
		  coreObjectTimesWorse);
}

#pragma mark - ordered relationship access

- (NSTimeInterval) timeToAccessFoundationObjectOrderedRelationship
{
	id value = nil;
	NSDate *start = [NSDate date];
	for (int i=0; i<ACCESS_ITERATIONS; i++)
	{
		value = foundationParent.arrayProperty;
	}
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / ACCESS_ITERATIONS;
	ETAssert([value isEqual: A(foundationChild1, foundationChild2, foundationChild3)]);
	return time;
}

- (NSTimeInterval) timeToAccessCoreObjectOrderedRelationship
{
	id value = nil;
	NSDate *start = [NSDate date];
	for (int i=0; i<ACCESS_ITERATIONS; i++)
	{
		value = coreobjectParent.contents;
	}
	NSTimeInterval time = [[NSDate date] timeIntervalSinceDate: start] / ACCESS_ITERATIONS;
	ETAssert([value isEqual: A(coreobjectChild1, coreobjectChild2, coreobjectChild3)]);
	return time;
}

- (void) testOrderedRelationshipAccess
{
	NSTimeInterval timeToAccessFoundationObjectOrderedRelationship = [self timeToAccessFoundationObjectOrderedRelationship];
	NSTimeInterval timeToAccessCoreObjectOrderedRelationship = [self timeToAccessCoreObjectOrderedRelationship];
	
	double coreObjectTimesWorse = timeToAccessCoreObjectOrderedRelationship / timeToAccessFoundationObjectOrderedRelationship;
	
	NSLog(@"Foundation object graph ordered relationship acces took %f us, core object graph ordered relationship access took %f us. CO is %f times wrose.",
		  timeToAccessFoundationObjectOrderedRelationship * 1000000,
		  timeToAccessCoreObjectOrderedRelationship * 1000000,
		  coreObjectTimesWorse);
}

@end
