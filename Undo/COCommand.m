#import "COCommand.h"
#import <EtoileFoundation/Macros.h>

#import "COCommandGroup.h"
#import "COCommandDeleteBranch.h"
#import "COCommandUndeleteBranch.h"
#import "COCommandSetBranchMetadata.h"
#import "COCommandSetCurrentBranch.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COCommitDescriptor.h"

// Edit types

static NSString * const kCOCommandTypeEditGroup = @"COCommandTypeEditGroup";
static NSString * const kCOCommandTypeDeleteBranch = @"COCommandTypeDeleteBranch";
static NSString * const kCOCommandTypeUndeleteBranch = @"COCommandTypeUndeleteBranch";
static NSString * const kCOCommandTypeSetBranchMetadata = @"COCommandTypeSetBranchMetadata";
static NSString * const kCOCommandTypeSetCurrentBranch = @"COCommandTypeSetCurrentBranch";
static NSString * const kCOCommandTypeSetCurrentVersionForBranch = @"COCommandTypeSetCurrentVersionForBranch";
static NSString * const kCOCommandTypeDeletePersistentRoot = @"COCommandTypeDeletePersistentRoot";
static NSString * const kCOCommandTypeUndeletePersistentRoot = @"COCommandTypeUndeletePersistentRoot";
static NSString * const kCOCommandTypeCreatePersistentRoot = @"COCommandTypeCreatePersistentRoot";

// Edit properties

static NSString * const kCOCommandType = @"COCommandType";
static NSString * const kCOCommandStoreUUID = @"COCommandStoreUUID";
static NSString * const kCOCommandPersistentRootUUID = @"COCommandPersistentRootUUID";
static NSString * const kCOCommandTimestamp = @"COCommandTimestamp";

@implementation COCommand

+ (NSDictionary *) mapping
{
    return D([COCommandGroup class], kCOCommandTypeEditGroup,
           [COCommandDeleteBranch class], kCOCommandTypeDeleteBranch,
           [COCommandUndeleteBranch class], kCOCommandTypeUndeleteBranch,
           [COCommandSetBranchMetadata class], kCOCommandTypeSetBranchMetadata,
           [COCommandSetCurrentBranch class], kCOCommandTypeSetCurrentBranch,
           [COCommandSetCurrentVersionForBranch class], kCOCommandTypeSetCurrentVersionForBranch,
           [COCommandDeletePersistentRoot class], kCOCommandTypeDeletePersistentRoot,
           [COCommandUndeletePersistentRoot class], kCOCommandTypeUndeletePersistentRoot, 
	       [COCommandCreatePersistentRoot class], kCOCommandTypeCreatePersistentRoot);
}

+ (COCommand *) commandWithPlist: (id)aPlist
{
    NSString *type = [aPlist objectForKey: kCOCommandType];
    
    // TODO: Allow for user defined types somehow
    
    Class cls = [[self mapping] objectForKey: type];

    if (cls != Nil)
    {
        return [[cls alloc] initWithPlist: aPlist];
    }
    else
    {
        [NSException raise: NSInvalidArgumentException format: @"invalid plist"];
        return nil;
    }
}

- (id) initWithPlist: (id)plist
{
    [NSException raise: NSInvalidArgumentException format: @"override"];
    return nil;
}

- (id) plist
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
 
    NSString *resultType = nil;
    NSDictionary *typeToClass = [COCommand mapping];
    for (NSString *type in typeToClass)
    {
        if ([self class] == [typeToClass objectForKey: type])
        {
            resultType = type;
        }
    }
    
    [result setObject: resultType forKey: kCOCommandType];
    return result;
}

- (COCommand *) inverse
{
    [NSException raise: NSInvalidArgumentException format: @"override"];
    return nil;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    [NSException raise: NSInvalidArgumentException format: @"override"];
    return NO;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    [NSException raise: NSInvalidArgumentException format: @"override"];
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"<%@: %p> %@", [self class], self, [self plist]];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"metadata", @"UUID", @"persistentRootUUID", @"branchUUID", @"date",
		  @"localizedTypeDescription", @"localizedShortDescription")];
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	return nil;
}

- (ETUUID *)persistentRootUUID
{
	return nil;
}

- (ETUUID *)branchUUID
{
	return nil;
}

- (NSDate *)date
{
	return nil;
}

- (NSDictionary *)metadata
{
	return nil;
}

- (NSString *)localizedTypeDescription
{
	// TODO: Override in subclasses to return a human-readable description
	return [self className];
}

- (NSString *)localizedShortDescription;
{
	return [[self metadata] objectForKey: kCOCommitMetadataShortDescription];
}

@end

@implementation COSingleCommand

@synthesize storeUUID = _storeUUID;
@synthesize persistentRootUUID = _persistentRootUUID;
@synthesize timestamp = _timestamp;

#pragma mark -
#pragma mark Date Serialization

+ (void)initialize
{
	if (self != [COSingleCommand class])
		return;

	/* Ensure -[NSDate isEqual:] compares -timeIntervalSinceReferenceDate, and 
	   we can convert -timeIntervalSinceReferenceDate to NSDate and back without 
	   any rounding. */
	NSDate *date = [NSDate date];
	ETAssert([date isEqual:
		[NSDate dateWithTimeIntervalSinceReferenceDate: [date timeIntervalSinceReferenceDate]]]);
}

// TODO: Factor basicNumberForDecimalNumber() in a common place so we can reuse it in COItem+JSON

/* 
 * Returning the parsed value as a NSNumber rather a NSDecimalNumber to ensure 
 * the rounding is the same than the serialized NSNumber object.
 *
 * Without this workaround, 123.456789012 roundtrip doesn't succeed on 10.7 (see
 * -testJSONDoubleEquality in TestItem.m)).
 *
 * For 123.456789012, NSJSONSerialization returns a NSDecimalNumber, but the 
 * rounding doesn't produce the same internal representation than a NSNumber 
 * initialized with the same double value.
 */
static inline NSNumber * basicNumberFromDecimalNumber(NSNumber *aValue)
{
	return [NSNumber numberWithDouble: [[aValue description] doubleValue]];
}

// NOTE: We serialize date objects as NSTimeInterval number to get a subsecond
// precision.
// Serializing dates as real dates strings using NSDateFormatter is very complex
// so we don't do it. See http://oleb.net/blog/2011/11/working-with-date-and-time-in-cocoa-part-2/

- (NSDate *)dateFromNumber: (NSNumber *)aNumber
{
	NILARG_EXCEPTION_TEST(aNumber);
	NSNumber *basicNumber = basicNumberFromDecimalNumber(aNumber);
	NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate: [basicNumber doubleValue]];

	ETAssert(date != nil);
	ETAssert([date timeIntervalSinceReferenceDate] == [basicNumber doubleValue]);
	return date;
}

- (NSNumber *)numberFromDate: (NSDate *)aDate
{
	NILARG_EXCEPTION_TEST(aDate);
	NSNumber *dateNumber = [NSNumber numberWithDouble: [aDate timeIntervalSinceReferenceDate]];

	ETAssert(dateNumber != nil);
	ETAssert([aDate timeIntervalSinceReferenceDate] == [dateNumber doubleValue]);
	return dateNumber;
}

#pragma mark -
#pragma mark Initialization

- (id) initWithPlist: (id)plist
{
    SUPERINIT;
    self.storeUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandStoreUUID]];
    self.persistentRootUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandPersistentRootUUID]];
	ETAssert([plist objectForKey: kCOCommandTimestamp] != nil);
    self.timestamp = [self dateFromNumber: [plist objectForKey: kCOCommandTimestamp]];
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    [result setObject: [_storeUUID stringValue] forKey: kCOCommandStoreUUID];
    [result setObject: [_persistentRootUUID stringValue] forKey: kCOCommandPersistentRootUUID];
    [result setObject: [self numberFromDate: _timestamp] forKey: kCOCommandTimestamp];
    return result;
}

- (id) copyWithZone:(NSZone *)zone
{
    COSingleCommand *aCopy = [[[self class] allocWithZone: zone] init];
    aCopy.storeUUID = _storeUUID;
    aCopy.persistentRootUUID = _persistentRootUUID;
    aCopy.timestamp = _timestamp;
    return aCopy;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COSingleCommand class]] == NO)
		return NO;

	return ([((COSingleCommand *)object)->_storeUUID isEqual: _storeUUID]
		 && [((COSingleCommand *)object)->_persistentRootUUID isEqual: _persistentRootUUID]
		 && [((COSingleCommand *)object)->_timestamp isEqual: _timestamp]);
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	return nil;
}

- (ETUUID *)persistentRootUUID
{
	return _persistentRootUUID;
}

- (ETUUID *)branchUUID
{
	return nil;
}

- (NSDate *)date
{
	return _timestamp;
}

@end
