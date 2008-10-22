/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COPersistentPool.h"
#import "COUtility.h"

#define RECORD_STACK_SIZE 10


@implementation COPersistentPool

- (id) init
{
	SUPERINIT

	_recordedObjectStack = [[NSMutableArray alloc] initWithCapacity: RECORD_STACK_SIZE];

	return self;
}

DEALLOC(DESTROY(_recordedObjectStack);)

/* Controlling Record Session */

/** Returns whether the receiver is currently in the middle of a record 
	session. */
- (BOOL) isRecording
{
	return ([self currentRecordSessionObject] != nil);
}

/** Returns the bottom object in the record session stack. */
- (id) currentRecordSessionObject
{
	return [_recordedObjectStack firstObject];
}

/** Returns the top object in the record session stack. */
- (id) currentRecordedObject
{
	return [_recordedObjectStack lastObject];
}

/** Begins a record group for a given managed core object.
	The behavior bound to the record session stack is the responsability of the 
	receiver and may be overriden in subclasses. 
	By default, the receiver only records the messages sent to the objects that 
	initiated the record session, the first one in the stack. All other objects 
	pushed onto the stack gets ignored by -recordInvocation:. */
- (void) beginRecordSessionWithObject: (id)object
{
	NSAssert1([_recordedObjectStack isEmpty], @"The record session stack must "
		@"be empty when a new record session is initiated in %@", self);

	[self beginRecordObject: object];
}

/** Ends a record group for a given managed core object. */
- (void) endRecordSession
{
	NSAssert1([[_recordedObjectStack lastObject] isEqual: 
		[self currentRecordSessionObject]], @"The record session stack must "
		@"contain only the object that initiated the session when the session "
		@"ends in %@", self);

	[self endRecord];

	NSAssert1([_recordedObjectStack isEmpty], @"The record session stack must "
		@"be empty when a record session has been terminated in %@", self);
}

/** Pushes the given object on the record session stack. 
	The behavior bound to the record session stack is the responsability of the 
	receiver and may be overriden in subclasses. */
- (void) beginRecordObject: (id)object
{
	ETDebugLog(@"---> Push on record stack: %@", object);
	[_recordedObjectStack addObject: object];
}

/** Pops the last recorded and pushed object from the record session stack. */
- (void) endRecord
{
	ETDebugLog(@"---> Pop from record stack: %@", [_recordedObjectStack lastObject]);
	[_recordedObjectStack removeLastObject];
}

@end
