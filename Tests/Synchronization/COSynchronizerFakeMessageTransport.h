/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

#import "COSynchronizerMessageTransport.h"

/**
 * This is a fake for the message transport mechanism between client and server,
 * that buffers messages in arrays, and executes them when requested.
 *
 * ProjectDemo will provide an implementation of a real one over XMPP.
 */
@interface FakeMessageTransport : NSObject <MessageTransport>
{
    COSynchronizerServer *server;
    NSMutableArray *serverMessages;

    NSMutableDictionary *clientForID;
    NSMutableDictionary *clientMessagesForID;
}

- (void)deliverMessages;
- (BOOL)deliverMessagesToClient;
- (BOOL)deliverMessagesToClient: (NSString *)clientID;
- (BOOL)deliverMessagesToServer;

@property (nonatomic, readonly) NSArray *serverMessages;

- (NSArray *)messagesForClient: (NSString *)anID;

@end
