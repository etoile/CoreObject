#import "COCommandGroup.h"
#import "COCommand.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COCommitDescriptor.h"
#import "CORevision.h"
#import <EtoileFoundation/Macros.h>

static NSString * const kCOCommandContents = @"COCommandContents";
static NSString * const kCOCommandMetadata = @"COCommandMetadata";

@implementation COCommandGroup

@synthesize UUID = _UUID, contents = _contents, metadata = _metadata;
@synthesize timestamp = _timestamp;

#pragma mark -
#pragma mark Date Serialization

/**
 * Rationale for presisting dates in Java's format (milliseconds since 1970-Jan-01):
 * - widely used
 * - int64_t, so can write exactly in base 10 unlike a double
 * - millisecond precision is good enough for our needs
 */
- (NSDate *)dateFromJavaTimestampNumber: (NSNumber *)aNumber
{
	NILARG_EXCEPTION_TEST(aNumber);
	const long long int javaDate = [aNumber longLongValue];
	
	return [NSDate dateWithTimeIntervalSince1970: javaDate / 1000.0];
}

- (NSNumber *)javaTimestampNumberFromDate: (NSDate *)aDate
{
	NILARG_EXCEPTION_TEST(aDate);
	const long long int javaDate = llrint([aDate timeIntervalSince1970] * 1000.0);
	
	return [NSNumber numberWithLongLong: javaDate];
}

#pragma mark -
#pragma mark Initialization

+ (void) initialize
{
	if (self != [COCommandGroup class])
		return;
	
	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (id)init
{
    SUPERINIT;
	_UUID = [ETUUID UUID];
    _contents = [[NSMutableArray alloc] init];
	_timestamp = [NSDate date];
    return self;
}

- (NSMutableArray *)commandsFromPropertyList: (NSDictionary *)plist
{
	NSMutableArray *commands = [NSMutableArray array];

    for (id subplist in [plist objectForKey: kCOCommandContents])
    {
        COCommand *command = [COCommand commandWithPropertyList: subplist];
        [commands addObject: command];
    }

	return commands;
}

- (id) initWithPropertyList: (id)plist
{
    SUPERINIT;
	_UUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandUUID]];
    _contents = [self commandsFromPropertyList: plist];
	_metadata = [plist objectForKey: kCOCommandMetadata];
	_timestamp = [self dateFromJavaTimestampNumber: [plist objectForKey: kCOCommandTimestamp]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
	
	[result setObject: [_UUID stringValue] forKey: kCOCommandUUID];
    [result setObject: [[_contents mappedCollection] propertyList] forKey: kCOCommandContents];
	if (_metadata != nil)
	{
		[result setObject: _metadata forKey: kCOCommandMetadata];
	}
	[result setObject: [self javaTimestampNumberFromDate: _timestamp] forKey: kCOCommandTimestamp];
	
    return result;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COCommandGroup class]] == NO)
		return NO;

	return ([((COCommandGroup *)object)->_UUID isEqual: _UUID]);
}

- (NSMutableArray *)inversedCommands
{
	NSMutableArray *inversedCommands = [NSMutableArray array];
	
    for (COCommand *command in _contents)
    {
		// Insert the inverses back to front, so the inverse of the most recent
		// action will be first.
        [inversedCommands insertObject: [command inverse] atIndex: 0];
    }

	return inversedCommands;
}

- (COCommand *) inverse
{
    COCommandGroup *inverse = [[COCommandGroup alloc] init];
    inverse.contents = [self inversedCommands];
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);

    for (COCommand *command in _contents)
    {
        if (![command canApplyToContext: aContext])
        {
            return NO;
        }
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);

    for (COCommand *command in _contents)
    {
        [command applyToContext: aContext];
    }
}

- (NSString *)kind
{
	return _(@"Change Group");
}

#pragma mark -
#pragma mark Track Node Protocol

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
	return _timestamp;
}

- (COCommitDescriptor *)commitDescriptor
{
	NSString *commitDescriptorId =
		[[self metadata] objectForKey: kCOCommitMetadataIdentifier];

	if (commitDescriptorId == nil)
		return nil;

	return [COCommitDescriptor registeredDescriptorForIdentifier: commitDescriptorId];
}

- (NSString *)localizedTypeDescription
{
	COCommitDescriptor *descriptor = [self commitDescriptor];

	if (descriptor == nil)
		return [[self metadata] objectForKey: kCOCommitMetadataTypeDescription];

	return [descriptor localizedTypeDescription];
}

- (NSString *)localizedShortDescription
{
	COCommitDescriptor *descriptor = [self commitDescriptor];

	if (descriptor == nil)
		return [[self metadata] objectForKey: kCOCommitMetadataShortDescription];
	
	return [descriptor localizedShortDescriptionWithArguments:
		[[self metadata] objectForKey: kCOCommitMetadataShortDescriptionArguments]];
}

#pragma mark -
#pragma mark Collection Protocol

- (BOOL)isOrdered
{
	return YES;
}

- (id)content
{
	return _contents;
}

- (NSArray *)contentArray
{
	return [NSArray arrayWithArray: [self content]];
}

@end
