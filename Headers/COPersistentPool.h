/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>

/* Private superclass of COObjectContext that may be used or removed in a later 
   version.
   This class implements the basic API for an invocation recording strategy  
   similar to object plane. The idea is to only record messages that cross the
   boundaries of the persistent pool Messages exchanged between objects within 
   the pool aren't recorded. */
@interface COPersistentPool : NSObject
{
	/* Successive senders inside a record session (invocation sequence) */
	NSMutableArray *_recordedObjectStack;
}

/* Controlling Record Session */

- (BOOL) isRecording;
- (id) currentRecordSessionObject;
- (id) currentRecordedObject;
- (void) beginRecordSessionWithObject: (id)object;
- (void) endRecordSession;
- (void) beginRecordObject: (id)object;
- (void) endRecord;
/*- (void) pushObjectInRecordSessionStack: 
- (void) popObjectFromRecordSessionStack:*/

@end
