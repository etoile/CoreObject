#import <CoreObject/CoreObject.h>

/**
 * To properly send a COSynchronizerRevision over the network, it's assumed
 * that you have also sent any referenced attachments if needed. This should
 * probably be done optimistaically and is left up to lower levels of the networking
 * protocol.
 */
@interface COSynchronizerRevision : NSObject
@property (nonatomic, readwrite, strong) COItemGraph *modifiedItems;
@property (nonatomic, readwrite, strong) ETUUID *revisionUUID;
@property (nonatomic, readwrite, strong) ETUUID *parentRevisionUUID;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;
@property (nonatomic, readwrite, strong) NSDate *date;
@end