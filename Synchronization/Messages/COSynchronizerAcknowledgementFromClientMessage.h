#import <CoreObject/CoreObject.h>

/**
 * Client sends this to server in response to all messages to let the server
 * know the message was received
 */
@interface COSynchronizerAcknowledgementFromClientMessage : NSObject
@property (nonatomic, readwrite, strong) NSString *clientID;
/**
 * Identifier for the message
 */
@property (nonatomic, readwrite, strong) ETUUID *lastRevisionUUIDSentByServer;
@end