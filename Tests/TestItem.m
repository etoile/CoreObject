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
    COItem *roundTrip = [[[COItem alloc] initWithJSONData: data] autorelease];
    UKObjectsEqual(item, roundTrip);
}

- (void) validateBinaryRoundTrip: (COItem*)item
{
    NSData *data = [item dataValue];
    COItem *roundTrip = [[[COItem alloc] initWithData: data] autorelease];
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
    [item setValue: [NSNumber numberWithInt: 1] forAttribute: @"1" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: -1] forAttribute: @"-1" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: 256] forAttribute: @"256" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: -256] forAttribute: @"-256" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: -65535] forAttribute: @"-65535" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: 65535] forAttribute: @"65535" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: 2000000000] forAttribute: @"2000000000" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithInt: -2000000000] forAttribute: @"-2000000000" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithLongLong: 8000000000] forAttribute: @"8000000000" type: kCOInt64Type];
    [item setValue: [NSNumber numberWithLongLong: -8000000000] forAttribute: @"-8000000000" type: kCOInt64Type];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOInt64Type];
    
    [item setValue: A([NSNumber numberWithInt: 1], [NSNumber numberWithLongLong: 8000000000])
      forAttribute: @"[1, 8000000000]"
              type: kCOArrayType | kCOInt64Type];

    [item setValue: S([NSNumber numberWithInt: 1], [NSNumber numberWithLongLong: 8000000000])
      forAttribute: @"(1, 8000000000)"
              type: kCOSetType | kCOInt64Type];

    [self validateRoundTrips: item];    
}

- (void) testDouble
{
	COMutableItem *item = [COMutableItem item];
    [item setValue: [NSNumber numberWithDouble: 3.14] forAttribute: @"3.14" type: kCODoubleType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCODoubleType];
    
    [item setValue: A([NSNumber numberWithDouble: 3.14], [NSNumber numberWithDouble: 123.456789012])
      forAttribute: @"[3.14, 123.456789012]"
              type: kCOArrayType | kCODoubleType];
    
    [item setValue: S([NSNumber numberWithDouble: 3.14], [NSNumber numberWithDouble: 123.456789012])
      forAttribute: @"(3.14, 123.456789012)"
              type: kCOSetType | kCODoubleType];
    
    [self validateRoundTrips: item];
}

- (void) testString
{
	COMutableItem *item = [COMutableItem item];
    [item setValue: @"abc" forAttribute: @"abc" type: kCOStringType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOStringType];
    
    [item setValue: A(@"abc", @"def")
      forAttribute: @"[abc, def]"
              type: kCOArrayType | kCOStringType];
    
    [item setValue: S(@"abc", @"def")
      forAttribute: @"(abc, def)"
              type: kCOSetType | kCOStringType];
    
    [self validateRoundTrips: item];
}

- (void) testBlob
{
    NSData *threeBytes = [NSData dataWithBytes: "xyz" length: 3];
    NSData *zeroBytes = [NSData data];
    
	COMutableItem *item = [COMutableItem item];
    [item setValue: zeroBytes forAttribute: @"zeroBytes" type: kCOBlobType];
    [item setValue: threeBytes forAttribute: @"xyz" type: kCOBlobType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOBlobType];
    
    [item setValue: A(zeroBytes, threeBytes)
      forAttribute: @"[zeroBytes, xyz]"
              type: kCOArrayType | kCOBlobType];
    
    [item setValue: S(zeroBytes, threeBytes)
      forAttribute: @"(zeroBytes, xyz)"
              type: kCOSetType | kCOBlobType];
    
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
    [item setValue: persistentRootPath forAttribute: @"persistentRootPath" type: kCOReferenceType];
    [item setValue: branchPath forAttribute: @"branchPath" type: kCOReferenceType];
    [item setValue: rootObject forAttribute: @"rootObject" type: kCOReferenceType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOReferenceType];
    
    [item setValue: A(persistentRootPath, branchPath, rootObject)
      forAttribute: @"[persistentRootPath, branchPath, rootObject]"
              type: kCOArrayType | kCOReferenceType];
    
    [item setValue: S(persistentRootPath, branchPath, rootObject)
      forAttribute: @"(persistentRootPath, branchPath, rootObject)"
              type: kCOSetType | kCOReferenceType];
    
    [self validateRoundTrips: item];
}

- (void) testCompositeReference
{
    ETUUID *rootObject = [ETUUID UUID];
    ETUUID *rootObject2 = [ETUUID UUID];
    
    COMutableItem *item = [COMutableItem item];
    [item setValue: rootObject forAttribute: @"rootObject" type: kCOCompositeReferenceType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOCompositeReferenceType];
    
    [item setValue: A(rootObject, rootObject2)
      forAttribute: @"[rootObject, rootObject2]"
              type: kCOArrayType | kCOCompositeReferenceType];
    
    [item setValue: S(rootObject, rootObject2)
      forAttribute: @"(rootObject, rootObject2)"
              type: kCOSetType | kCOCompositeReferenceType];
    
    [self validateRoundTrips: item];
}

- (void) testAttachment
{
    NSData *threeBytes = [NSData dataWithBytes: "xyz" length: 3];
    NSData *zeroBytes = [NSData data];
    
	COMutableItem *item = [COMutableItem item];
    [item setValue: zeroBytes forAttribute: @"zeroBytes" type: kCOAttachmentType];
    [item setValue: threeBytes forAttribute: @"xyz" type: kCOAttachmentType];
    [item setValue: [NSNull null] forAttribute: @"null" type: kCOAttachmentType];
    
    [item setValue: A(zeroBytes, threeBytes)
      forAttribute: @"[zeroBytes, xyz]"
              type: kCOArrayType | kCOAttachmentType];
    
    [item setValue: S(zeroBytes, threeBytes)
      forAttribute: @"(zeroBytes, xyz)"
              type: kCOSetType | kCOAttachmentType];
    
    [self validateRoundTrips: item];
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
    
    [mutable setValue: @"name 2" forAttribute: @"name"];
    
    UKObjectsNotEqual(immutable, mutable);
}

- (void) testEmptySet
{
	COMutableItem *item1 = [COMutableItem item];
	[item1 setValue: [NSSet set] forAttribute: @"set" type: kCOStringType | kCOSetType];
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