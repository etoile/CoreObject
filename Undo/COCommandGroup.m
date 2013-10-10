#import "COCommandGroup.h"
#import "COCommand.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "CORevision.h"
#import <EtoileFoundation/Macros.h>

static NSString * const kCOCommandContents = @"COCommandContents";

@implementation COCommandGroup

@synthesize contents = _contents;

+ (void) initialize
{
	if (self != [COCommandGroup class])
		return;
	
	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (id)init
{
    SUPERINIT;
    _contents = [[NSMutableArray alloc] init];
    return self;
}

- (id) initWithPlist: (id)plist
{
    SUPERINIT;
    
    NSMutableArray *edits = [NSMutableArray array];
    for (id editPlist in [plist objectForKey: kCOCommandContents])
    {
        COCommand *subEdit = [COCommand commandWithPlist: editPlist];
        [edits addObject: subEdit];
    }
    
    self.contents = edits;
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (COCommand *subEdit in _contents)
    {
        id subEditPlist = [subEdit plist];
        [edits addObject: subEditPlist];
    }
    [result setObject: edits forKey: kCOCommandContents];
    return result;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COCommandGroup class]] == NO)
		return NO;

	return ([((COCommandGroup *)object)->_contents isEqual: _contents]);
}

- (COCommand *) inverse
{
    COCommandGroup *inverse = [[COCommandGroup alloc] init];
    
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

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	// TODO: Return a transaction/batch UUID probably
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
	return [[_contents firstObject] date];
}

- (CORevision *)revisionWithMetadata
{
	for (COCommand *command in _contents)
	{
		BOOL hasNewRevision =
			([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]]
		 		|| [command isKindOfClass: [COCommandCreatePersistentRoot class]]);

		if (hasNewRevision)
		{
			return [(COCommandSetCurrentVersionForBranch *)command revision];
		}
	}
	return nil;
}

- (NSString *)localizedShortDescription
{
	return [[self revisionWithMetadata] localizedShortDescription];
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
