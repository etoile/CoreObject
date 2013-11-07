#import <CoreObject/CoreObject.h>

/**
 * The server is pushing revisions to the client (the client is not expecting them)
 *
 * Client should send a COSynchronizerAcknowledgementFromClientMessage in response.
 */
@interface COSynchronizerPushedRevisionsToClientMessage : NSObject
/** Array of COSynchronizerRevision */
@property (nonatomic, readwrite, strong) NSArray *revisions;
@end
