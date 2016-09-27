/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  September 2014
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

#import "COSynchronizerMessageTransport.h"

/**
 * This is a fake for the message transport mechanism between client and server;
 * unlike FakeMessageTransport which buffers the messages and delivers them on
 * request, this one sends a message as soon as it is received.
 */
@interface ImmediateMessageTransport : NSObject <MessageTransport>
{
    COSynchronizerServer *server;
    NSMutableDictionary *clientForID;
}

@end
