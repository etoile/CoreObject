#import "TestCommon.h"
#import <UnitKit/UnitKit.h>
#import "COItem.h"
#import "COItem+Binary.h"
#import "COItem+JSON.h"

@interface TestItem : NSObject <UKTest> {
	
}

@end

@implementation TestItem

- (void) testBasic
{
	COMutableItem *i1 = [COMutableItem item];
	i1.schemaName = @"org.etoile.test";
    
	[i1 setValue: S(@"hello", @"world")
	forAttribute: @"contents"
			type: kCOStringType | kCOSetType];
	
	// test round trip to JSON
	{
		id json = [i1 JSONData];
        
		COMutableItem *i1clone = [[[COMutableItem alloc] initWithJSONData: json] autorelease];
		UKObjectsEqual(i1, i1clone);
	}
    
    // test round trip to the binary format
    {
		COMutableItem *i1clone = [[[COMutableItem alloc] initWithData: [i1 dataValue]] autorelease];
		UKObjectsEqual(i1, i1clone);        
    }
}

- (COItem *) roundTrip: (COItem *)anItem
{
    return [[[COMutableItem alloc] initWithData: [anItem dataValue]] autorelease];
}

- (void) testSchemaName
{
    COMutableItem *i1 = [COMutableItem item];
	i1.schemaName = nil;

    UKNil([[self roundTrip: i1] schemaName]);
    
    i1.schemaName = @"";
    UKObjectsEqual(@"", [[self roundTrip: i1] schemaName]);
    
    i1.schemaName = @"x";
    UKObjectsEqual(@"x", [[self roundTrip: i1] schemaName]);
}

- (void) testMutability
{	
	COItem *immutable = [COItem itemWithTypesForAttributes: D(@(kCOStringType | kCOSetType), @"key1",
															  @(kCOStringType | kCOArrayType), @"key2",
															  @(kCOStringType), @"name")
									   valuesForAttributes: D([NSMutableSet setWithObject: @"a"], @"key1",	
															  [NSMutableArray arrayWithObject: @"A"], @"key2",
															  @"my name", @"name")];

	UKRaisesException([(COMutableItem *)immutable setValue: @"foo" forAttribute: @"bar" type: kCOStringType]);

	UKRaisesException([[immutable valueForAttribute: @"key1"] addObject: @"b"]);
	UKRaisesException([[immutable valueForAttribute: @"key2"] addObject: @"B"]);
	
	COMutableItem *mutable = [[immutable mutableCopy] autorelease];
	
	UKDoesNotRaiseException([[mutable valueForAttribute: @"key1"] addObject: @"b"]);
	UKDoesNotRaiseException([[mutable valueForAttribute: @"key2"] addObject: @"B"]);
	
	UKIntsEqual(1, [[immutable valueForAttribute: @"key1"] count]);
	UKIntsEqual(1, [[immutable valueForAttribute: @"key2"] count]);
	
	UKIntsEqual(2, [[mutable valueForAttribute: @"key1"] count]);
	UKIntsEqual(2, [[mutable valueForAttribute: @"key2"] count]);
	
	UKRaisesException([[mutable valueForAttribute: @"name"] appendString: @"xxx"]);
}

- (void) testEquality
{
	COItem *immutable = [COItem itemWithTypesForAttributes: D([NSNumber numberWithInt: kCOStringType | kCOSetType], @"key1",
															  [NSNumber numberWithInt: kCOStringType | kCOArrayType], @"key2",
															  [NSNumber numberWithInt: kCOStringType], @"name")
									   valuesForAttributes: D([NSMutableSet setWithObject: @"a"], @"key1",	
															  [NSMutableArray arrayWithObject: @"A"], @"key2",
															  @"my name", @"name")];
	COMutableItem *mutable = [[immutable mutableCopy] autorelease];
	
	UKObjectsEqual(immutable, mutable);
	UKObjectsEqual(mutable, immutable);
}

- (void) testEmptySet
{
	COMutableItem *item1 = [COMutableItem item];
	[item1 setValue: [NSSet set] forAttribute: @"set" type: kCOStringType | kCOSetType];
	
	COMutableItem *item2 = [COMutableItem item];
	
	UKObjectsNotEqual(item2, item1);
}

- (void) testBinaryExportForSetAttribute
{
	COMutableItem *item1 = [COMutableItem item];
	[item1 setValue: S(@"a", @"b", @"c") forAttribute: @"set" type: kCOStringType | kCOSetType];
		
	UKObjectsEqual(item1, [[[COItem alloc] initWithData: [item1 dataValue]] autorelease]);
}

- (void) testBinaryExportForArrayAttribute
{
	COMutableItem *item1 = [COMutableItem item];
	[item1 setValue: A(@"a", @"b", @"c") forAttribute: @"array" type: kCOStringType | kCOArrayType];
    
	UKObjectsEqual(item1, [[[COItem alloc] initWithData: [item1 dataValue]] autorelease]);
}

- (void) testNullSerialization
{
    COMutableItem *item1 = [COMutableItem item];
    [item1 setValue: [NSNull null] forAttribute:  @"name" type: kCOStringType];
    [item1 setValue: A([NSNull null], [NSNull null]) forAttribute:  @"people" type: kCOArrayType | kCOStringType];
    
    COItem *item2 = [[[COItem alloc] initWithData: [item1 dataValue]] autorelease];
    
    UKObjectsEqual(item1, item2);
    UKObjectsEqual([NSNull null], [item2 valueForAttribute: @"name"]);
    UKObjectsEqual(A([NSNull null], [NSNull null]), [item2 valueForAttribute: @"people"]);
    
    COItem *item3 = [[[COItem alloc] initWithJSONData: [item1 JSONData]] autorelease];
    
    UKObjectsEqual(item3, item1);
    UKObjectsEqual([NSNull null], [item1 valueForAttribute: @"name"]);
    UKObjectsEqual(A([NSNull null], [NSNull null]), [item1 valueForAttribute: @"people"]);
}

//- (void) testNamedType
//{
//	COMutableItem *item1 = [COMutableItem item];
//	item1 setValue: [NSSet set] forAttribute: @"set" type: [kCOStringType | kCOSetType namedType: @"testName"]];
//
//    UKObjectsEqual(@"testName", [[item1 typeForAttribute: @"set"] name]);
//}

@end