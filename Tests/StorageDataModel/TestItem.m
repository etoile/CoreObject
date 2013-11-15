#import "TestCommon.h"
#import <UnitKit/UnitKit.h>
#import "COItem.h"
#import "COItem+Binary.h"
#import "COItem+JSON.h"

@interface TestItem : NSObject <UKTest> {
	
}

@end

@implementation TestItem

- (void) validateJSONRoundTrip: (COItem*)item
{
    NSData *data = [item JSONData];
    COItem *roundTrip = [[COItem alloc] initWithJSONData: data];
    UKObjectsEqual(item, roundTrip);
}

- (void) validateBinaryRoundTrip: (COItem*)item
{
    NSData *data = [item dataValue];
    COItem *roundTrip = [[COItem alloc] initWithData: data];
    UKObjectsEqual(item, roundTrip);
}

- (void) validateRoundTrips: (COItem*)item
{
    [self validateJSONRoundTrip: item];
    [self validateBinaryRoundTrip: item];
}

- (void) testInt
{
	COMutableItem *item = [COMutableItem item];
    [item setValue: [NSNumber numberWithInt: 1] forAttribute: @"1" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: -1] forAttribute: @"-1" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: 256] forAttribute: @"256" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: -256] forAttribute: @"-256" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: -65535] forAttribute: @"-65535" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: 65535] forAttribute: @"65535" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: 2000000000] forAttribute: @"2000000000" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithInt: -2000000000] forAttribute: @"-2000000000" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithLongLong: 8000000000] forAttribute: @"8000000000" type: kCOTypeInt64];
    [item setValue: [NSNumber numberWithLongLong: -8000000000] forAttribute: @"-8000000000" type: kCOTypeInt64];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeInt64];
    
    [item setValue: A([NSNumber numberWithInt: 1], [NSNumber numberWithLongLong: 8000000000])
      forAttribute: @"[1, 8000000000]"
              type: kCOTypeArray | kCOTypeInt64];

    [item setValue: S([NSNumber numberWithInt: 1], [NSNumber numberWithLongLong: 8000000000])
      forAttribute: @"(1, 8000000000)"
              type: kCOTypeSet | kCOTypeInt64];

    [self validateRoundTrips: item];    
}

/* See basicNumberFromDecimalNumber() in COItem+JSON.m */
- (void) testJSONDoubleEquality
{
	NSNumber *value = [NSNumber numberWithDouble: 123.456789012];
	NSNumber *decimalValue = [NSDecimalNumber numberWithDouble: 123.456789012];
	NSData *data = [NSJSONSerialization dataWithJSONObject: D(value, @"number") options: 0 error: NULL];
	NSNumber *roundTripValue =
		[[NSJSONSerialization JSONObjectWithData: data options: 0 error: NULL] objectForKey: @"number"];
	NSNumber *newValue = [NSNumber numberWithDouble: [roundTripValue doubleValue]];
	NSNumber *newValueFromDesc = [NSNumber numberWithDouble: [[roundTripValue description] doubleValue]];

	UKTrue([[NSDecimalNumber defaultBehavior] scale] == NSDecimalNoScale);

	NSLog(@"Double representation in JSON: %@",
		  [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);

	/* Rounding is visible in the ouput for numbers that contain more than two 
	   decimals on 10.7 (e.g. 123.45 output is the same for all numbers). */
	NSLog(@"value            doubleValue: %.20f, description: %@, class: %@",
		  [value doubleValue], value, [value class]);
	NSLog(@"decimalValue     doubleValue: %.20f, description: %@, class: %@",
		  [decimalValue doubleValue], decimalValue, [decimalValue class]);
	NSLog(@"roundTripValue   doubleValue: %.20f, description: %@, class: %@",
		  [roundTripValue doubleValue], roundTripValue, [roundTripValue class]);
	NSLog(@"newValue         doubleValue: %.20f, description: %@, class: %@",
		  [newValue doubleValue], newValue, [newValue class]);
	NSLog(@"newValueFromDesc doubleValue: %.20f, description: %@, class: %@",
		  [newValueFromDesc doubleValue], newValueFromDesc, [newValueFromDesc class]);

	UKTrue([value compare: newValueFromDesc] == NSOrderedSame);
	UKTrue([newValueFromDesc compare: value] == NSOrderedSame);
}

- (void) testDouble
{
	COMutableItem *item = [COMutableItem item];
    [item setValue: [NSNumber numberWithDouble: 3.14] forAttribute: @"3.14" type: kCOTypeDouble];
	[item setValue: [NSNumber numberWithDouble: 123.456789012] forAttribute: @"123.456789012" type: kCOTypeDouble];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeDouble];
    
    [item setValue: A([NSNumber numberWithDouble: 3.14], [NSNumber numberWithDouble: 123.456789012])
      forAttribute: @"[3.14, 123.456789012]"
              type: kCOTypeArray | kCOTypeDouble];
    
    [item setValue: S([NSNumber numberWithDouble: 3.14], [NSNumber numberWithDouble: 123.456789012])
      forAttribute: @"(3.14, 123.456789012)"
              type: kCOTypeSet | kCOTypeDouble];
    
    [self validateRoundTrips: item];
}

- (void) testString
{
	COMutableItem *item = [COMutableItem item];
    [item setValue: @"abc" forAttribute: @"abc" type: kCOTypeString];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeString];
    
    [item setValue: A(@"abc", @"def")
      forAttribute: @"[abc, def]"
              type: kCOTypeArray | kCOTypeString];
    
    [item setValue: S(@"abc", @"def")
      forAttribute: @"(abc, def)"
              type: kCOTypeSet | kCOTypeString];
    
    [self validateRoundTrips: item];
}

- (void) testBlob
{
    NSData *threeBytes = [NSData dataWithBytes: "xyz" length: 3];
    NSData *zeroBytes = [NSData data];
    
	COMutableItem *item = [COMutableItem item];
    [item setValue: zeroBytes forAttribute: @"zeroBytes" type: kCOTypeBlob];
    [item setValue: threeBytes forAttribute: @"xyz" type: kCOTypeBlob];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeBlob];
    
    [item setValue: A(zeroBytes, threeBytes)
      forAttribute: @"[zeroBytes, xyz]"
              type: kCOTypeArray | kCOTypeBlob];
    
    [item setValue: S(zeroBytes, threeBytes)
      forAttribute: @"(zeroBytes, xyz)"
              type: kCOTypeSet | kCOTypeBlob];
    
    [self validateRoundTrips: item];
}

- (void) testReference
{
    ETUUID *persistentRoot = [ETUUID UUID];
    ETUUID *branch = [ETUUID UUID];
    ETUUID *rootObject = [ETUUID UUID];
    
    COPath *persistentRootPath = [COPath pathWithPersistentRoot: persistentRoot];
    COPath *branchPath = [COPath pathWithPersistentRoot: persistentRoot branch: branch];
        
    COMutableItem *item = [COMutableItem item];
    [item setValue: persistentRootPath forAttribute: @"persistentRootPath" type: kCOTypeReference];
    [item setValue: branchPath forAttribute: @"branchPath" type: kCOTypeReference];
    [item setValue: rootObject forAttribute: @"rootObject" type: kCOTypeReference];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeReference];
    
    [item setValue: A(persistentRootPath, branchPath, rootObject)
      forAttribute: @"[persistentRootPath, branchPath, rootObject]"
              type: kCOTypeArray | kCOTypeReference];
    
    [item setValue: S(persistentRootPath, branchPath, rootObject)
      forAttribute: @"(persistentRootPath, branchPath, rootObject)"
              type: kCOTypeSet | kCOTypeReference];
    
    [self validateRoundTrips: item];
}

- (void) testCompositeReference
{
    ETUUID *rootObject = [ETUUID UUID];
    ETUUID *rootObject2 = [ETUUID UUID];
    
    COMutableItem *item = [COMutableItem item];
    [item setValue: rootObject forAttribute: @"rootObject" type: kCOTypeCompositeReference];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeCompositeReference];
    
    [item setValue: A(rootObject, rootObject2)
      forAttribute: @"[rootObject, rootObject2]"
              type: kCOTypeArray | kCOTypeCompositeReference];
    
    [item setValue: S(rootObject, rootObject2)
      forAttribute: @"(rootObject, rootObject2)"
              type: kCOTypeSet | kCOTypeCompositeReference];
    
    [self validateRoundTrips: item];
}

- (void) testAttachment
{
    NSData *threeBytes = [NSData dataWithBytes: "xyz" length: 3];
    NSData *zeroBytes = [NSData data];
    
	COMutableItem *item = [COMutableItem item];
    [item setValue: zeroBytes forAttribute: @"zeroBytes" type: kCOTypeAttachment];
    [item setValue: threeBytes forAttribute: @"xyz" type: kCOTypeAttachment];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOTypeAttachment];
    
    [item setValue: A(zeroBytes, threeBytes)
      forAttribute: @"[zeroBytes, xyz]"
              type: kCOTypeArray | kCOTypeAttachment];
    
    [item setValue: S(zeroBytes, threeBytes)
      forAttribute: @"(zeroBytes, xyz)"
              type: kCOTypeSet | kCOTypeAttachment];
    
    [self validateRoundTrips: item];
}


- (COItem *) roundTrip: (COItem *)anItem
{
    return [[COMutableItem alloc] initWithData: [anItem dataValue]];
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
	COItem *immutable = [COItem itemWithTypesForAttributes: D(@(kCOTypeString | kCOTypeSet), @"key1",
															  @(kCOTypeString | kCOTypeArray), @"key2",
															  @(kCOTypeString), @"name")
									   valuesForAttributes: D([NSMutableSet setWithObject: @"a"], @"key1",	
															  [NSMutableArray arrayWithObject: @"A"], @"key2",
															  @"my name", @"name")];

	UKRaisesException([(COMutableItem *)immutable setValue: @"foo" forAttribute: @"bar" type: kCOTypeString]);

	UKRaisesException([[immutable valueForAttribute: @"key1"] addObject: @"b"]);
	UKRaisesException([[immutable valueForAttribute: @"key2"] addObject: @"B"]);
	
	COMutableItem *mutable = [immutable mutableCopy];
	
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
	COItem *immutable = [COItem itemWithTypesForAttributes: D([NSNumber numberWithInt: kCOTypeString | kCOTypeSet], @"key1",
															  [NSNumber numberWithInt: kCOTypeString | kCOTypeArray], @"key2",
															  [NSNumber numberWithInt: kCOTypeString], @"name")
									   valuesForAttributes: D([NSMutableSet setWithObject: @"a"], @"key1",	
															  [NSMutableArray arrayWithObject: @"A"], @"key2",
															  @"my name", @"name")];
	COMutableItem *mutable = [immutable mutableCopy];
	
	UKObjectsEqual(immutable, mutable);
	UKObjectsEqual(mutable, immutable);
    
    [mutable setValue: @"name 2" forAttribute: @"name"];
    
    UKObjectsNotEqual(immutable, mutable);
}

- (void) testEmptySet
{
	COMutableItem *item1 = [COMutableItem item];
	[item1 setValue: [NSSet set] forAttribute: @"set" type: kCOTypeString | kCOTypeSet];
    [self validateRoundTrips: item1];
    
	COMutableItem *item2 = [COMutableItem item];
    
	UKObjectsNotEqual(item2, item1);
}

- (void) testEmptyObject
{
	COMutableItem *item1 = [COMutableItem item];
    [self validateRoundTrips: item1];
}

@end