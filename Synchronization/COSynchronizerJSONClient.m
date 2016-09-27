/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerJSONClient.h"
#import "COSynchronizerJSONUtils.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

@implementation COSynchronizerJSONClient

@synthesize delegate, client, paused;

- (instancetype) init
{
    SUPERINIT;
    queuedMessages = [NSMutableArray new];
    return self;
}
- (void) sendPropertyListToServer: (id)aPropertyList
{
    NSString *text = [COSynchronizerJSONUtils serializePropertyList: aPropertyList];
    if (paused)
    {
        [queuedMessages addObject: @{ @"text" : text, @"type" : @"outgoing" }];
    }
    else
    {
        [delegate JSONClient: self sendTextToServer: text];
    }
}

- (void) sendPushToServer: (COSynchronizerPushedRevisionsFromClientMessage *)message
{
    id plist = [NSMutableDictionary new];
    plist[@"clientID"] = message.clientID;
    plist[@"revisions"] = [COSynchronizerJSONUtils propertyListForRevisionsArray:message.revisions];
    plist[@"lastRevisionUUIDSentByServer"] = [message.lastRevisionUUIDSentByServer stringValue];
    plist[@"class"] = @"COSynchronizerPushedRevisionsFromClientMessage";
    [self sendPropertyListToServer: plist];
}

- (void) handleResponsePropertyList: (id)plist
{
    COSynchronizerResponseToClientForSentRevisionsMessage *message = [COSynchronizerResponseToClientForSentRevisionsMessage new];
    message.lastRevisionUUIDSentByClient = [ETUUID UUIDWithString: plist[@"lastRevisionUUIDSentByClient"]];
    message.revisions = [COSynchronizerJSONUtils revisionsArrayForPropertyList: plist[@"revisions"]];
    [client handleResponseMessage: message];
}

- (void) handlePushPropertyList: (id)plist
{
    COSynchronizerPushedRevisionsToClientMessage *message = [COSynchronizerPushedRevisionsToClientMessage new];
    message.revisions = [COSynchronizerJSONUtils revisionsArrayForPropertyList: plist[@"revisions"]];
    [client handlePushMessage: message];
}

- (void) handleSetupPropertyList: (id)plist
{
    COSynchronizerPersistentRootInfoToClientMessage *message = [COSynchronizerPersistentRootInfoToClientMessage new];
    message.persistentRootUUID = [ETUUID UUIDWithString: plist[@"persistentRootUUID"]];
    message.persistentRootMetadata = plist[@"persistentRootMetadata"];
    message.branchUUID = [ETUUID UUIDWithString: plist[@"branchUUID"]];
    message.branchMetadata = plist[@"branchMetadata"];
    message.currentRevision = [[COSynchronizerRevision alloc] initWithPropertyList: plist[@"currentRevision"]];
    [client handleSetupMessage: message];
    
    ETAssert(client.branch != nil);
    [self.delegate JSONClient: self didStartSharingOnBranch: client.branch];
}

- (void) receiveTextFromServer:(NSString *)text
{
    if (paused)
    {
        [queuedMessages addObject: @{ @"text" : text, @"type" : @"incoming" }];
    }
    else
    {
        [self processIncomingText: text];
    }
}

- (void) processIncomingText: (NSString *)text
{
    id propertyList = [COSynchronizerJSONUtils deserializePropertyList: text];
    
    NSString *type = propertyList[@"class"];
    if ([type isEqual: @"COSynchronizerResponseToClientForSentRevisionsMessage"])
    {
        [self handleResponsePropertyList: propertyList];
    }
    else if ([type isEqual: @"COSynchronizerPushedRevisionsToClientMessage"])
    {
        [self handlePushPropertyList: propertyList];
    }
    else if ([type isEqual: @"COSynchronizerPersistentRootInfoToClientMessage"])
    {
        [self handleSetupPropertyList: propertyList];
    }
    else
    {
        NSLog(@"COSynchronizerJSONClient: unknown message type: %@", type);
    }
}

- (void) processOutgoingText: (NSString *)text
{
    [delegate JSONClient: self sendTextToServer: text];
}

- (void) processQueuedMessages
{
    NSArray *messages = [NSArray arrayWithArray: queuedMessages];
    [queuedMessages removeAllObjects];
    for (NSDictionary *msg in messages)
    {
        if ([msg[@"type"] isEqualToString: @"incoming"])
        {
            [self processIncomingText: msg[@"text"]];
        }
        else
        {
            [self processOutgoingText: msg[@"text"]];
        }
    }
}

- (void)setPaused: (BOOL)flag
{
    paused = flag;
    if (!paused)
    {
        [self processQueuedMessages];
    }
}

@end
