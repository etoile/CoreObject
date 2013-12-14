/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

/**
 * The client is pushing revisions to the server.
 *
 * Server should send a COSynchronizerResponseToClientForSentRevisionsMessage
 * in response
 */
@interface COSynchronizerPushedRevisionsFromClientMessage : NSObject
@property (nonatomic, readwrite, strong) NSString *clientID;
/** 
 * Array of COSynchronizerRevision
 * The parent of the first revision in the array should be the last revision
 * the client received from the server.
 */
@property (nonatomic, readwrite, strong) NSArray *revisions;
/**
 * Identifier for the message
 */
@property (nonatomic, readwrite, strong) ETUUID *lastRevisionUUIDSentByServer;

@end