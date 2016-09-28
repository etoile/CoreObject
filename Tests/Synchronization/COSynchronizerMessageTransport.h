/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  September 2014
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@protocol MessageTransport <COSynchronizerClientDelegate, COSynchronizerServerDelegate>

- (instancetype)initWithSynchronizerServer: (COSynchronizerServer *)aServer;
- (void)addClient: (COSynchronizerClient *)aClient;

@property (nonatomic, readonly, strong) COSynchronizerServer *server;
@property (nonatomic, readonly) NSArray *serverMessages;

- (NSArray *)messagesForClient: (NSString *)anID;
- (BOOL)deliverMessagesToServer;
- (BOOL)deliverMessagesToClient;

@end
