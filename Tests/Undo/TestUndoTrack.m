/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

#define TEST_TRACK @"TestUndoTrack"

@interface TestUndoTrack : EditingContextTestCase <UKTest>
{
    COUndoTrack *_track;
	COUndoTrack *_track2;
	COUndoTrack *_patternTrack;
}

@end

@implementation TestUndoTrack

#pragma mark - test infrastructure

- (void) checkSettingCurrentNodeOfTrack: (COUndoTrack *)aTrack
									 to: (id<COTrackNode>)aNode
							undoesNodes: (NSArray *)undoNodes
							redoesNodes: (NSArray *)redoNodes
{
	
}

#pragma mark - tests

- (id) init
{
    SUPERINIT;
    
    _track = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
	[_track clear];
	
	_track2 = [COUndoTrack trackForName: TEST_TRACK @"2" withEditingContext: ctx];
	[_track2 clear];
	
	_patternTrack = [COUndoTrack trackForPattern: TEST_TRACK @"*" withEditingContext: ctx];
	[_patternTrack clear];
	
	return self;
}

- (void) testEmptyTrack
{
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance]), [_track nodes]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], _track.currentNode);
}

- (void) testEmptyTrackSetCurrentNode
{
	UKDoesNotRaiseException([_track setCurrentNode: [COEndOfUndoTrackPlaceholderNode sharedInstance]]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], _track.currentNode);	
}

- (void) testSingleRecord
{
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance]), [_track nodes]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [_track currentNode]);
		
	COCommandGroup *group = [[COCommandGroup alloc] init];
	[_track recordCommand: group];

	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group), [_track nodes]);
	UKObjectsEqual(group, [_track currentNode]);
		
	// Check with a second COUndoTrack
	
	COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
	UKObjectsNotSame(_track, secondTrackInstance);
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group), [secondTrackInstance nodes]);
	UKObjectsEqual(group, [secondTrackInstance currentNode]);
}

- (void) testTwoRecords
{
	COCommandGroup *group1 = [[COCommandGroup alloc] init];
	COCommandGroup *group2 = [[COCommandGroup alloc] init];
	[_track recordCommand: group1];
	[_track recordCommand: group2];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group2), [_track nodes]);
	UKObjectsEqual(group2, [_track currentNode]);
	UKObjectsEqual(group1.UUID, group2.parentUUID);
	
	// Check with a second COUndoTrack
	
	COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
	UKObjectsNotSame(_track, secondTrackInstance);
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group2), [secondTrackInstance nodes]);
	UKObjectsEqual(group2, [secondTrackInstance currentNode]);
	UKObjectsEqual(group1.UUID, [(COCommandGroup *)[secondTrackInstance currentNode] parentUUID]);
	
	// Check in the store
	
	COUndoTrackState *state = [_track.store stateForTrackName: TEST_TRACK];
	UKObjectsEqual(TEST_TRACK, state.trackName);
	UKObjectsEqual(group2.UUID, state.headCommandUUID);
	UKObjectsEqual(group2.UUID, state.currentCommandUUID);
}

- (void) testUndoAndRedoOneNode
{
	COCommandGroup *group1 = [[COCommandGroup alloc] init];
	COCommandGroup *group2 = [[COCommandGroup alloc] init];
	[_track recordCommand: group1];
	[_track recordCommand: group2];
	
	[_track setCurrentNode: group1];
	
	UKObjectsEqual(group1, [_track currentNode]);

	// Check with a second COUndoTrack
	{
		COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
		UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group2), [secondTrackInstance nodes]);
		UKObjectsEqual(group1, [secondTrackInstance currentNode]);
		UKNil([(COCommandGroup *)[secondTrackInstance currentNode] parentUUID]);
	}

	[_track setCurrentNode: group2];
	
	UKObjectsEqual(group2, [_track currentNode]);

	{
		COUndoTrack *secondTrackInstance = [COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx];
		UKObjectsEqual(group2, [secondTrackInstance currentNode]);
	}
}

- (void) testDivergentCommands
{
	COCommandGroup *group1 = [[COCommandGroup alloc] init];
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1];
	[_track recordCommand: group1a];
	[_track setCurrentNode: group1];
	[_track recordCommand: group1b];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group1b), [_track nodes]);
	UKObjectsEqual(S(group1, group1a, group1b), SA([_track allCommands]));
	UKIntsEqual(3, [S(group1, group1a, group1b) count]);
}

- (void) testSetCurrentNodeToDivergentNode
{
	COCommandGroup *group1 = [[COCommandGroup alloc] init];
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1];
	[_track recordCommand: group1a];
	[_track setCurrentNode: group1];
	[_track recordCommand: group1b];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group1b), [_track nodes]);

	[_track setCurrentNode: group1a];

	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1, group1a), [_track nodes]);
}

- (void) testDivergentNodesWhereCommonAncestorIsPlaceholderNode
{
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1a];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a), [_track nodes]);
	UKObjectsEqual(group1a, _track.currentNode);
	
	[_track setCurrentNode: [COEndOfUndoTrackPlaceholderNode sharedInstance]];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a), [_track nodes]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], _track.currentNode);
	
	[_track recordCommand: group1b];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1b), [_track nodes]);
	UKObjectsEqual(group1b, _track.currentNode);
	
	[_track setCurrentNode: group1a];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a), [_track nodes]);
	UKObjectsEqual(group1a, _track.currentNode);
}

- (void) testNavigateToDivergentNodesFromPlaceholderNode
{
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1a];
	[_track setCurrentNode: [COEndOfUndoTrackPlaceholderNode sharedInstance]];
	[_track recordCommand: group1b];
	[_track setCurrentNode: [COEndOfUndoTrackPlaceholderNode sharedInstance]];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1b), [_track nodes]);
	
	[_track setCurrentNode: group1a];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a), [_track nodes]);
	UKObjectsEqual(group1a, _track.currentNode);
}

- (void) testUndoOnPatternTrack
{
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance]), [_patternTrack nodes]);
	
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	COCommandGroup *group2a = [[COCommandGroup alloc] init];
	COCommandGroup *group2b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1a];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a), [_patternTrack nodes]);
	
	[_track2 recordCommand: group2a];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a, group2a), [_patternTrack nodes]);
	
	[_track recordCommand: group1b];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a, group2a, group1b), [_patternTrack nodes]);
	
	[_track2 recordCommand: group2b];
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a, group2a, group1b, group2b), [_patternTrack nodes]);
	
	[_patternTrack undo];
	
	UKObjectsEqual(group1b, [_track currentNode]);
	UKObjectsEqual(group2a, [_track2 currentNode]);
	UKObjectsEqual(group1b, [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
	UKObjectsEqual(group2a, [[COUndoTrack trackForName: TEST_TRACK @"2" withEditingContext: ctx] currentNode]);
	
	[_patternTrack undo];
	
	UKObjectsEqual(group1a, [_track currentNode]);
	UKObjectsEqual(group2a, [_track2 currentNode]);
	UKObjectsEqual(group1a, [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
	UKObjectsEqual(group2a, [[COUndoTrack trackForName: TEST_TRACK @"2" withEditingContext: ctx] currentNode]);
	
	[_patternTrack undo];
	
	UKObjectsEqual(group1a, [_track currentNode]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [_track2 currentNode]);
	UKObjectsEqual(group1a, [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [[COUndoTrack trackForName: TEST_TRACK @"2" withEditingContext: ctx] currentNode]);
	
	[_patternTrack undo];
	
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [_track currentNode]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [_track2 currentNode]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [[COUndoTrack trackForName: TEST_TRACK withEditingContext: ctx] currentNode]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [[COUndoTrack trackForName: TEST_TRACK @"2" withEditingContext: ctx] currentNode]);
}

- (void) testUndoOnPatternTrackObservedTracks
{
	COCommandGroup *group1a = [[COCommandGroup alloc] init];
	COCommandGroup *group1b = [[COCommandGroup alloc] init];
	COCommandGroup *group2a = [[COCommandGroup alloc] init];
	COCommandGroup *group2b = [[COCommandGroup alloc] init];
	
	[_track recordCommand: group1a];
	[_track2 recordCommand: group2a];
	[_track recordCommand: group1b];
	[_track2 recordCommand: group2b];

	// NOTE: This has the effect of reordering the commands in [_patternTrack nodes]
	[_track undo];
	
	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group1a, group2a, group2b, group1b), [_patternTrack nodes]);
	UKObjectsEqual(group2b, [_patternTrack currentNode]);
	
	[_track undo];

	UKObjectsEqual(A([COEndOfUndoTrackPlaceholderNode sharedInstance], group2a, group2b, group1a, group1b), [_patternTrack nodes]);
	UKObjectsEqual(group2b, [_patternTrack currentNode]);
}

// TODO: Test mixing commands between tracks illegally

@end
