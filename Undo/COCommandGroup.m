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
    return self;
}

- (id) initWithPropertyList: (id)plist
{
    SUPERINIT;
    
	self.UUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandUUID]];

    NSMutableArray *edits = [NSMutableArray array];
    for (id editPlist in [plist objectForKey: kCOCommandContents])
    {
        COCommand *subEdit = [COCommand commandWithPropertyList: editPlist];
        [edits addObject: subEdit];
    }
    
    self.contents = edits;

	_metadata = [plist objectForKey: kCOCommandMetadata];

    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    
	[result setObject: [self.UUID stringValue] forKey: kCOCommandUUID];
	
    NSMutableArray *edits = [NSMutableArray array];
    for (COCommand *subEdit in _contents)
    {
        id subEditPlist = [subEdit propertyList];
        [edits addObject: subEditPlist];
    }
    [result setObject: edits forKey: kCOCommandContents];

	if (_metadata != nil)
	{
		[result setObject: _metadata forKey: kCOCommandMetadata];
	}
    return result;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COCommandGroup class]] == NO)
		return NO;

	return ([((COCommandGroup *)object)->_UUID isEqual: _UUID]);
}

- (COCommand *) inverse
{
    COCommandGroup *inverse = [[COCommandGroup alloc] init];
    inverse.UUID = [ETUUID new];
	
    NSMutableArray *edits = [NSMutableArray array];
    for (COCommand *subEdit in _contents)
    {
        COCommand *subEditInverse = [subEdit inverse];
		// Insert the inverses back to front, so the inverse of the most recent action will be first.
        [edits insertObject: subEditInverse atIndex: 0];
    }
    inverse.contents = edits;
    
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    for (COCommand *subEdit in _contents)
    {
        if (![subEdit canApplyToContext: aContext])
        {
            return NO;
        }
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    for (COCommand *subEdit in _contents)
    {
        [subEdit applyToContext: aContext];
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
	return [[_contents firstObject] date];
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
