#import "TestCommon.h"

@interface BenchmarkItem : NSObject <UKTest>
@end


@implementation BenchmarkItem

#define ITERATIONS 1000000

#define ATTRIBUTES 10

static NSString *attributes[ATTRIBUTES] = { @"name", @"age", @"location", @"tags",
    @"lat", @"lon", @"photo", @"friends", @"firstname", @"lastname"};

static COType types[ATTRIBUTES] = { kCOTypeString, kCOTypeInt64, kCOTypeString, kCOTypeArray | kCOTypeReference,
    kCOTypeDouble, kCOTypeDouble, kCOTypeBlob, kCOTypeSet | kCOTypeString, kCOTypeString, kCOTypeString };

static id values[ATTRIBUTES];

+ (void)initialize
{
    if (self == [BenchmarkItem class])
    {
        values[0] = @"john";
        values[1] = @(21);
        values[2] = @"Toronto";
        values[3] = @[[ETUUID UUID], [ETUUID UUID]];
        values[4] = @(12.34);
        values[5] = @(56.78);
        values[6] = [[ETUUID UUID] dataValue];
        values[7] = [NSSet setWithObjects: @"bob", @"alice" @"carol", nil];
        values[8] = @"John";
        values[9] = @"Smith";
    }
}

- (void) testWrite
{
    NSDate *startDate = [NSDate date];
    COMutableItem *item = [[COMutableItem alloc] init];
    
    for (NSUInteger i=0; i<ITERATIONS; i++)
    {
        [item setValue: values[i % ATTRIBUTES]
          forAttribute: attributes[i % ATTRIBUTES]
                  type: types[i % ATTRIBUTES]];
    }
    
    NSLog(@"writing %d attributes in COMutableItem took %lf ms", ITERATIONS, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

- (void) testRead
{
    NSDate *startDate = [NSDate date];
    COMutableItem *item = [[COMutableItem alloc] init];
    
    for (NSUInteger i=0; i<10; i++)
    {
        [item setValue: values[i]
          forAttribute: attributes[i]
                  type: types[i]];
    }
    
	BOOL ok = YES;
    for (NSUInteger i=0; i<ITERATIONS; i++)
    {
		// N.B. These could be UKObjectsEqual checks, but this test case would become about 100x slower
        ok = ok && [values[i % ATTRIBUTES] isEqual: [item valueForAttribute: attributes[i % ATTRIBUTES]]];
        ok = ok && (types[i % ATTRIBUTES] == [item typeForAttribute: attributes[i % ATTRIBUTES]]);
    }
    UKTrue(ok);
	
    NSLog(@"reading %d attributes in COItem took %lf ms", ITERATIONS, 1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

@end