/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

/**
 * Server received the revisions that the client pushed, and is returning
 * the final history sequence.
 *
 * Sent in response to a COSynchronizerPushedRevisionsFromClientMessage
 * from a client.
 *
 * Client should send a COSynchronizerAcknowledgementFromClientMessage
 * in response to this message.
 */
@interface COSynchronizerResponseToClientForSentRevisionsMessage : NSObject
/**
 * To identify this message, the UUID of the last revision in the revisions
 * array of the COSynchronizerPushedRevisionsFromClientMessage that this
 * is a response to
 */
@property (nonatomic, readwrite, strong) ETUUID *lastRevisionUUIDSentByClient;
/** Array of COSynchronizerRevision */
@property (nonatomic, readwrite, strong) NSArray *revisions;
@end
