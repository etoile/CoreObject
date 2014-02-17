/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommand.h"
#import <EtoileFoundation/Macros.h>

#import "COCommandGroup.h"
#import "COCommandDeleteBranch.h"
#import "COCommandUndeleteBranch.h"
#import "COCommandSetBranchMetadata.h"
#import "COCommandSetPersistentRootMetadata.h"
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
static NSString * const kCOCommandTypeSetPersistentRootMetadata = @"COCommandTypeSetPersistentRootMetadata";
static NSString * const kCOCommandTypeSetCurrentBranch = @"COCommandTypeSetCurrentBranch";
static NSString * const kCOCommandTypeSetCurrentVersionForBranch = @"COCommandTypeSetCurrentVersionForBranch";
static NSString * const kCOCommandTypeDeletePersistentRoot = @"COCommandTypeDeletePersistentRoot";
static NSString * const kCOCommandTypeUndeletePersistentRoot = @"COCommandTypeUndeletePersistentRoot";
static NSString * const kCOCommandTypeCreatePersistentRoot = @"COCommandTypeCreatePersistentRoot";

// Edit properties

static NSString * const kCOCommandType = @"COCommandType";
static NSString * const kCOCommandStoreUUID = @"COCommandStoreUUID";
static NSString * const kCOCommandPersistentRootUUID = @"COCommandPersistentRootUUID";

@implementation COCommand

@synthesize parentUndoTrack = _parentUndoTrack;
@synthesize storeUUID = _storeUUID;
@synthesize persistentRootUUID = _persistentRootUUID;

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
	       [COCommandCreatePersistentRoot class], kCOCommandTypeCreatePersistentRoot,
		   [COCommandSetPersistentRootMetadata class], kCOCommandTypeSetPersistentRootMetadata);
}

+ (COCommand *) commandWithPropertyList: (id)aPlist parentUndoTrack: (COUndoTrack *)aParent
{
    NSString *type = [aPlist objectForKey: kCOCommandType];
    
    // TODO: Allow for user defined types somehow
    
    Class cls = [[self mapping] objectForKey: type];

    if (cls != Nil)
    {
        return [[cls alloc] initWithPropertyList: aPlist parentUndoTrack: aParent];
    }
    else
    {
        [NSException raise: NSInvalidArgumentException format: @"invalid plist"];
        return nil;
    }
}

- (id) initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    SUPERINIT;
	_parentUndoTrack = aParent;
    _storeUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandStoreUUID]];
    _persistentRootUUID = [ETUUID UUIDWithString: [plist objectForKey: kCOCommandPersistentRootUUID]];
    return self;
}

- (id) propertyList
{
    NSDictionary *typeToClass = [COCommand mapping];
    for (NSString *type in typeToClass)
    {
        if ([self class] == typeToClass[type])
        {
			NSMutableDictionary *result = [NSMutableDictionary dictionary];
			result[kCOCommandType] = type;
			
			[result setObject: [_storeUUID stringValue] forKey: kCOCommandStoreUUID];
			[result setObject: [_persistentRootUUID stringValue] forKey: kCOCommandPersistentRootUUID];
			return result;
        }
    }
	
	ETAssertUnreachable();
    return nil;
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
    return [NSString stringWithFormat: @"<%@: %p> %@", [self class], self, [self propertyList]];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"metadata", @"UUID", @"persistentRootUUID", @"branchUUID", @"date",
		  @"localizedTypeDescription", @"localizedShortDescription")];
}

- (NSString *)kind
{
	return nil;
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
	return [self kind];
}

- (NSString *)localizedShortDescription
{
	return nil;
}

- (id) copyWithZone:(NSZone *)zone
{
    COCommand *aCopy = [[[self class] allocWithZone: zone] init];
    aCopy->_storeUUID = _storeUUID;
    aCopy->_persistentRootUUID = _persistentRootUUID;
    return aCopy;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [self class]] == NO)
		return NO;
	
	return [((COCommand *)object)->_storeUUID isEqual: _storeUUID]
	&& [((COCommand *)object)->_persistentRootUUID isEqual: _persistentRootUUID];
}

@end
