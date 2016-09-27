/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

/**
 * The server is pushing revisions to the client (the client is not expecting them)
 *
 * Client should send a COSynchronizerAcknowledgementFromClientMessage in response.
 */
@interface COSynchronizerPushedRevisionsToClientMessage : NSObject
{
    NSArray *_revisions;
}

/** Array of COSynchronizerRevision */
@property (nonatomic, readwrite, copy) NSArray *revisions;
@end
