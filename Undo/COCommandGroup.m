/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COCommandGroup.h"
#import "COCommand.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COCommitDescriptor.h"
#import "CORevision.h"
#import "CODateSerialization.h"
#import "COUndoTrackStore.h"
#import "COUndoTrack.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import <EtoileFoundation/Macros.h>

NSString * const kCOCommandUUID = @"COCommandUUID";
static NSString * const kCOCommandTimestamp = @"COCommandTimestamp";
static NSString * const kCOCommandContents = @"COCommandContents";
static NSString * const kCOCommandMetadata = @"COCommandMetadata";

@implementation COCommandGroup

@synthesize UUID = _UUID, contents = _contents, metadata = _metadata;
@synthesize timestamp = _timestamp;
@synthesize sequenceNumber = _sequenceNumber;
@synthesize parentUUID = _parentUUID;
@synthesize trackName = _trackName;

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

- (instancetype) initWithSerializedCommand: (COUndoTrackSerializedCommand *)aCommand
									 owner: (COUndoTrack *)anOwner
{
	SUPERINIT;
	_parentUndoTrack = anOwner;
	_contents = [self commandsFromPropertyList: aCommand.JSONData
							   parentUndoTrack: anOwner];
	_metadata = aCommand.metadata;
	_UUID = aCommand.UUID;
	if (aCommand.parentUUID == nil)
	{
		_parentUUID = [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID];
	}
	else
	{
		_parentUUID = aCommand.parentUUID;
	}
	_timestamp = aCommand.timestamp;
	_sequenceNumber = aCommand.sequenceNumber;
	_trackName = aCommand.trackName;
	return self;
}

- (COUndoTrackSerializedCommand *) serializedCommand
{
	COUndoTrackSerializedCommand *cmd = [COUndoTrackSerializedCommand new];
	cmd.JSONData = [self commandsPropertyList];
	cmd.metadata = _metadata;
	cmd.UUID = _UUID;
	if ([_parentUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]])
	{
		cmd.parentUUID = nil;
	}
	else
	{
		cmd.parentUUID = _parentUUID;
	}
	cmd.trackName = _trackName;
	cmd.timestamp = _timestamp;
	cmd.sequenceNumber = _sequenceNumber;
	return cmd;
}

- (id) commandsPropertyList
{
	return @{kCOCommandContents : [[_contents mappedCollection] propertyList]};
}

- (NSMutableArray *)commandsFromPropertyList: (NSDictionary *)plist parentUndoTrack: (COUndoTrack *)aParent
{
	NSMutableArray *commands = [NSMutableArray array];

    for (id subplist in [plist objectForKey: kCOCommandContents])
    {
        COCommand *command = [COCommand commandWithPropertyList: subplist
												parentUndoTrack: aParent];
        [commands addObject: command];
    }

	return commands;
}

- (BOOL)isEqual: (id)object
{
	if ([object isKindOfClass: [COCommandGroup class]] == NO)
		return NO;

	return ([((COCommandGroup *)object)->_UUID isEqual: _UUID]);
}

- (NSUInteger) hash
{
	return [_UUID hash];
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

- (NSMutableArray *)copiedCommands
{
	NSMutableArray *commands = [NSMutableArray array];
    for (COCommand *command in _contents)
    {
		[commands addObject: [command copy]];
    }
	return commands;
}

- (COCommandGroup *) inverse
{
    COCommandGroup *inverse = [[COCommandGroup alloc] init];
    inverse.contents = [self inversedCommands];
    return inverse;
}

- (id) copyWithZone: (NSZone *)aZone
{
    COCommandGroup *copied = [[COCommandGroup alloc] init];
    copied.contents = [self copiedCommands];
    return copied;
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

- (void) addToStoreTransaction: (COStoreTransaction *)txn withRevisionMetadata: (NSDictionary *)metadata assumingEditingContextState: (COEditingContext *)ctx
{
	NILARG_EXCEPTION_TEST(ctx);
	NILARG_EXCEPTION_TEST(txn);
	
    for (COCommand *command in _contents)
    {
        [command addToStoreTransaction: txn withRevisionMetadata: metadata assumingEditingContextState: ctx];
    }
}

- (NSString *)kind
{
	return _(@"Change Group");
}

- (COUndoTrack *)parentUndoTrack
{
	return _parentUndoTrack;
}

- (void)setParentUndoTrack:(COUndoTrack *)parentUndoTrack
{
	_parentUndoTrack = parentUndoTrack;
	for (COCommand *childCommand in self.contents)
	{
		childCommand.parentUndoTrack = parentUndoTrack;
	}
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)persistentRootUUID
{
	// This is kind of a hack
	for (COCommand *command in [_contents reverseObjectEnumerator])
	{
		if (command.persistentRootUUID != nil)
			return command.persistentRootUUID;
	}
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

- (id<COTrackNode>)parentNode
{
	ETAssert(self.parentUUID != nil);
	
	if ([self.parentUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]])
		return [COEndOfUndoTrackPlaceholderNode sharedInstance];
	
	return [_parentUndoTrack commandForUUID: self.parentUUID];
}

- (id<COTrackNode>)mergeParentNode
{
	return nil;
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

#pragma mark -

- (COCommandGroup *) parentCommand
{
	return nil;// [_owner commandForUUID: _parentCommandUUID];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"COCommandGroup %@", _UUID];
}

@end
