/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class COSynchronizerRevision;

/**
 * Contains everything a client needs to get set up
 *
 * Client should send a COSynchronizerAcknowledgementFromClientMessage
 * in response.
 */
@interface COSynchronizerPersistentRootInfoToClientMessage : NSObject

@property (nonatomic, readwrite, copy) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, copy) NSDictionary *persistentRootMetadata;
@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (nonatomic, readwrite, copy) NSDictionary *branchMetadata;
@property (nonatomic, readwrite, strong) COSynchronizerRevision *currentRevision;

@end
