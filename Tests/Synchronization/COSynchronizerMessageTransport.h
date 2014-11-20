/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  September 2014
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@protocol MessageTransport <COSynchronizerClientDelegate, COSynchronizerServerDelegate>

- (id) initWithSynchronizerServer: (COSynchronizerServer *)aServer;
- (void) addClient: (COSynchronizerClient *)aClient;

@property (nonatomic, readonly, strong) COSynchronizerServer *server;

- (NSArray *) serverMessages;
- (NSArray *) messagesForClient: (NSString *)anID;
- (BOOL) deliverMessagesToServer;
- (BOOL) deliverMessagesToClient;

@end
